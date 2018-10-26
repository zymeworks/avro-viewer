module AvroViewer.RenderPanels exposing (..)

import AvroViewer.Model exposing (..)
import AvroViewer.Util as Util
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Dict exposing (Dict)


{--
    This module handles the heavy lifting of rendering data within records in a panel format.
    This function renders the top container of panel view, handling the case where no path is
    selected yet.

    Panel view works by taking a path and splitting it. Each element in the path is then rendered as
    a panel, traversing through that value one level deep. If a property in that panel is of type
    Sequence, an event handler is attached which on click will append said property to the list of
    active path. The function re-renders with a new element in the path list, creating a new panel
    with the selected property.
--}


renderPanelView : Model -> Html Msg
renderPanelView model =
    let
        renderPanels =
            case model.panelPath of
                -- Handle the case where the user hasn't selected anything yet
                [] ->
                    [ renderPanel [] Nothing model.parsedRecords ]

                -- Case of an active path present to render panels for
                _ ->
                    let
                        {--
                            To render a panel we need two pieces of information:
                                1. A path list of where to find the local data to render within the root WrappedJsonValue tree
                                2. a (Maybe) path item of which element in the panel should be highlighted

                            ( [], File )           ( [File], Index )      ( [File, Index], Nothing )
                            +--------+             +--------+             +--------+
                            |        |             |        |             |        |

                            This function takes:
                                [ 1, 2, 3 ]
                            and returns:
                                [ ( [], 1 ), ( [ 1 ], 2 ), ( [ 1, 2 ], 3 ), ( [ 1, 2, 3 ], Nothing ) ]
                            Where each tuple is
                                ( list of path up to this point, selected item for the panel i.e. the reference of the next open panel )
                        --}
                        pathPyramid =
                            let
                                buildPathTuples ( index, el ) =
                                    let
                                        nextElement =
                                            Util.getByIndex index model.panelPath
                                    in
                                        ( List.take index model.panelPath, nextElement )
                            in
                                model.panelPath
                                    |> List.indexedMap (,)
                                    |> List.map buildPathTuples
                                    |> List.reverse
                                    |> List.append [ ( model.panelPath, Nothing ) ]
                                    |> List.reverse
                    in
                        -- Render panels with transformed active path
                        List.map
                            (\( path, selectedPartial ) -> renderPanel path selectedPartial model.parsedRecords)
                            pathPyramid
    in
        div []
            [ div [ class "panel-breadcrumbs" ]
                [ div [ class "breadcrumb-header" ] [ text "Current Path:" ]
                , div [ class "breadcrumb-list" ] (renderPanelBreadcrumbs model.panelPath)
                ]
            , div [ class "panel-content", id panelContainerID ]
                [ div [ class "panel-wrapper" ] renderPanels
                ]
            ]



{--
    Given a path list, split it and render each item out
--}


renderPanelBreadcrumbs : List PathPartial -> List (Html Msg)
renderPanelBreadcrumbs pathList =
    let
        breadcrumb : PathPartial -> List (Html Msg) -> List (Html Msg)
        breadcrumb path els =
            let
                item =
                    case path of
                        File fname ->
                            span [] [ text fname ]

                        Index ind ->
                            span [] [ text ("Datum " ++ (toString ind)) ]

                        Key key ->
                            span [] [ text key ]
            in
                List.append els [ item ]
    in
        List.foldl breadcrumb [] pathList



{--
    Actually render a panel, given the data, a path, and which element to highlight

    Args
        pathToRender        (List PathPartial)    aaaa
        partialToHighlight  (Maybe PathPartial)   aaaa
        records             (List Record)         The top level of data in our model, each record contains an Array Sequence of WrappedJsonValue of data

    Returns
        Rendered html of a panel    (List Html)
--}


renderPanel : List PathPartial -> Maybe PathPartial -> List Record -> Html Msg
renderPanel pathToRender partialToHighlight records =
    let
        fullPath =
            case partialToHighlight of
                Just p ->
                    List.append pathToRender [ p ]

                Nothing ->
                    pathToRender

        -- Traverse the path with the give object to find the data we need to render in this panel
        treeToRender =
            if (List.length pathToRender) == 0 then
                WrappedValue JsNull
            else
                Util.getSubtree records pathToRender
    in
        --There are two cases here, 1: pathToRender empty so this is a File panel, or 2: this is a WrappedJsonValue panel
        case pathToRender of
            [] ->
                -- When there is no  path list (the first panel) Render the file list panel
                -- with <Maybe> highlighted selected file
                let
                    highlightEntry fname =
                        if fname == (Util.pathPartialToString partialToHighlight) then
                            " active"
                        else
                            ""

                    pathBuilder : String -> List PathPartial
                    pathBuilder fname =
                        [ File fname ]

                    renderFileRow record =
                        div
                            [ class <| "entry" ++ (highlightEntry record.filename)
                            , onClick <| SetPanelPath (pathBuilder record.filename)
                            ]
                            [ i [ class "fa fa-fw fa-file-o panel-file-icon" ] []
                            , span [] [ text <| record.filename ]
                            , i [ class "expand-panel-icon fa fa-fw fa-caret-right" ] []
                            ]
                in
                    div []
                        [ div [ class "panel" ]
                            [ div [ class "panel-header" ] [ text "File List" ]
                            , div [ class "panel-body" ] (List.map renderFileRow records)
                            ]
                        ]

            _ ->
                -- Otherwise, there is a path to the WrappedJSONValue subtree we want to render
                div []
                    [ div [ class "panel" ]
                        [ div [ class "panel-header", title <| toString pathToRender ]
                            [ div [ class "breadcrumb-list small-breadcrumbs" ] (renderPanelBreadcrumbs pathToRender)

                            --, i [ class "fa fa-bars" ] []
                            , determinePanelExportCSV treeToRender
                            ]
                        , div [ class "panel-body json no-indent" ] [ renderWrappedJsonPanel treeToRender partialToHighlight ]
                        ]
                    ]



{--
    Render the entries of a WrappedJsonValue (Render primitives, Dict keys, and Array indices)
--}


renderWrappedJsonPanel : WrappedJsonValue -> Maybe PathPartial -> Html Msg
renderWrappedJsonPanel val partialToHighlight =
    let
        renderColourCodedPrimitive val =
            case val of
                JsBool value ->
                    span [ class "value bool" ]
                        [ text (toString value) ]

                JsString value ->
                    span [ class "value string" ]
                        [ text (toString value) ]

                JsInt value ->
                    span [ class "value int" ]
                        [ text (toString value) ]

                JsFloat value ->
                    span [ class "value float" ]
                        [ text (toString value) ]

                JsNull ->
                    span [ class "value" ]
                        [ text "Null" ]
    in
        case val of
            WrappedValue primitive ->
                renderColourCodedPrimitive primitive

            WrappedSequence sequence ->
                case sequence of
                    ArraySequence config list ->
                        let
                            renderIndexItems ind val =
                                let
                                    pathToSet =
                                        List.append config.path [ Index ind ]

                                    entryIsActive =
                                        if ind == (Util.pathPartialToInt partialToHighlight) then
                                            " active"
                                        else
                                            ""

                                    entryLabel =
                                        if config.isTopLevelContainer then
                                            "Datum " ++ (toString ind)
                                        else
                                            "Array Item " ++ (toString ind)
                                in
                                    div
                                        [ class <| "entry" ++ entryIsActive
                                        , onClick <| SetPanelPath pathToSet
                                        ]
                                        [ span [] [ text entryLabel ]
                                        , i [ class "expand-panel-icon fa fa-fw fa-caret-right" ] []
                                        ]
                        in
                            if config.tabular then
                                renderListTable config list
                            else
                                div [] (List.indexedMap renderIndexItems list)

                    HashSequence config dict ->
                        let
                            highlightEntry key =
                                if key == (Util.pathPartialToString partialToHighlight) then
                                    " active"
                                else
                                    ""

                            pathBuilder key =
                                List.append config.path [ Key key ]

                            renderDictKey ( key, value ) =
                                case value of
                                    WrappedValue primitive ->
                                        div [ class "entry static" ]
                                            [ span [ class "key" ] [ text (key ++ ": ") ]
                                            , renderColourCodedPrimitive primitive
                                            ]

                                    WrappedSequence sequence ->
                                        div
                                            [ class <| "entry" ++ (highlightEntry key)
                                            , onClick <| SetPanelPath (pathBuilder key)
                                            ]
                                            [ span [ class "sequence-key" ] [ text key ]
                                            , i [ class "expand-panel-icon fa fa-fw fa-caret-right" ] []
                                            ]
                        in
                            div [] (List.map renderDictKey (Dict.toList dict))


determinePanelExportCSV : WrappedJsonValue -> Html Msg
determinePanelExportCSV val =
    case Util.dataIfTabular val of
        Just subtree ->
            div
                [ class "panel-csv-btn btn"
                , onClick (DownloadLocalCSV subtree)
                ]
                [ i [ class "fa fa-fw fa-table" ] []
                , span [] [ text "Download CSV" ]
                ]

        Nothing ->
            text ""



-- Render a table from a list of WrappedJsonValue, called when config.tabular is True
-- The List of WrappedJsonValue at this point has been determined to have all primitive values


renderListTable : SequenceContainer -> List WrappedJsonValue -> Html Msg
renderListTable topConfig list =
    let
        -- First deal with splicing the data in the case of paging
        numRows =
            List.length list

        pagedList =
            if numRows <= topConfig.limit then
                list
            else
                list
                    |> List.drop topConfig.offset
                    |> List.take topConfig.limit

        -- If tableKeyPriority is set, reorder the columns and rows,
        -- sort the key values so the priority key is first
        sortFn : ( String, WrappedJsonValue ) -> ( String, WrappedJsonValue ) -> Order
        sortFn ( a, b ) ( c, d ) =
            if a == tableKeyPriority && c /= tableKeyPriority then
                LT
            else if a /= tableKeyPriority && c == tableKeyPriority then
                GT
            else
                compare a c

        {--
            Take the first element in a record list, MUST be dictionary
            Unpack key values, and repeat keys in table header
        --}
        renderHeader : Maybe WrappedJsonValue -> List (Html Msg)
        renderHeader firstElement =
            let
                renderHeaderKey ( key, value ) =
                    th [] [ text key ]
            in
                case firstElement of
                    Just entry ->
                        case entry of
                            WrappedValue primitive ->
                                [ text "" ]

                            WrappedSequence sequence ->
                                case sequence of
                                    ArraySequence config list ->
                                        [ text "" ]

                                    HashSequence config dict ->
                                        let
                                            keyValues =
                                                dict
                                                    |> Dict.toList
                                                    |> List.sortWith sortFn
                                        in
                                            [ th [] [ text "" ] ]
                                                ++ List.map renderHeaderKey keyValues

                    Nothing ->
                        []

        {--
            Take a list of contents (wrapped JSON values, MUST be dictionary)
            render their values in table rows
        --}
        renderRow : Int -> WrappedJsonValue -> Html Msg
        renderRow index entry =
            let
                renderHeaderKey ( key, value ) =
                    case value of
                        WrappedValue primitive ->
                            case primitive of
                                JsBool value ->
                                    td [ class "value bool" ] [ text <| toString value ]

                                JsString value ->
                                    td [ class "value string" ] [ div [ class "string-cell" ] [ text value ] ]

                                JsInt value ->
                                    td [ class "value int" ] [ text <| toString value ]

                                JsFloat value ->
                                    td [ class "value float" ] [ text <| toString value ]

                                JsNull ->
                                    td [ class "value null" ] [ text "" ]

                        WrappedSequence sequence ->
                            text ""
            in
                case entry of
                    WrappedValue primitive ->
                        text ""

                    WrappedSequence sequence ->
                        case sequence of
                            ArraySequence config list ->
                                text ""

                            HashSequence config dict ->
                                let
                                    collapsedClass =
                                        if config.tableRowCollapsed == True then
                                            "collapsed"
                                        else
                                            ""

                                    rowNumber =
                                        index + topConfig.offset + 1

                                    keyValues =
                                        dict
                                            |> Dict.toList
                                            |> List.sortWith sortFn

                                    updatedConfig =
                                        { config | tableRowCollapsed = not config.tableRowCollapsed }
                                in
                                    tr [ class collapsedClass, onDoubleClick <| MutateSequenceContainer config updatedConfig ]
                                        ([ th [] [ text <| toString rowNumber ] ]
                                            ++ List.map renderHeaderKey keyValues
                                        )
    in
        table [ class "data-table" ]
            [ thead []
                [ tr [] (renderHeader <| List.head pagedList)
                ]
            , tbody [] (List.indexedMap renderRow pagedList)
            ]
