module AvroViewer.RenderTree exposing (..)

import AvroViewer.Model exposing (..)
import AvroViewer.RenderPanels exposing (..)
import AvroViewer.Util as Util
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Dict exposing (Dict)


{--
    Render a file container, handling collapse/expand functionality.
    This function renders file name, extrapolates length of records, and
    extracts the avro Datums from the top level WrappedJsonValue Sequence.
    Contents are then rendered via renderWrappedValue.
--}


renderTreeView : Record -> Html Msg
renderTreeView record =
    let
        expanded =
            if record.expanded == True then
                "expanded"
            else
                ""

        -- Check if the top level wrapper/container is tabular, if it is, avoid rendering excessive padding so the table looks nice
        topLevelIsTabular =
            Util.nodeIsTabular record.contents

        downloadCsvButton =
            if topLevelIsTabular then
                let
                    val =
                        Util.dataIfTabular record.contents
                in
                    case val of
                        Just array ->
                            button [ class "ml2 btn btn-transparent pa2 ph4 f7 bl-grey", onClick (DownloadLocalCSV array) ] [ text "Download CSV" ]

                        Nothing ->
                            text ""
            else
                text ""

        containerClass =
            if topLevelIsTabular then
                "no-indent"
            else
                ""

        fileClass =
            if topLevelIsTabular then
                "f6 mt3 collapse-area"
            else
                "file-contents collapse-area"

        limitReachedWarning =
            if record.recordLimitReached then
                div [ class "limit-reached-banner" ] [ text "Warning: File contains a lot of records. Showing only first 10,000" ]
            else
                text ""
    in
        div [ class ("file-row " ++ expanded) ]
            [ limitReachedWarning
            , div [ class "file-header" ]
                [ i [ class "collapse-icon fa fa-plus-square-o", onClick (ExpandFileRow record) ] []
                , i [ class "expand-icon fa fa-minus-square-o", onClick (ExpandFileRow record) ] []
                , div [ class "file-name", onClick (ExpandFileRow record) ]
                    [ text record.filename, span [ class "file-records-length" ] [ text <| (toString record.count) ++ " items" ] ]
                , button [ class "btn btn-transparent pa2 ph4 f7 ml-auto", onClick <| DownloadAsJson record ] [ text "Download JSON" ]
                , downloadCsvButton
                ]
            , div [ class fileClass ]
                [ div [ class <| "json " ++ containerClass ]
                    [ renderWrappedValue record.contents ]
                ]
            ]


recordLengthText : Int -> String
recordLengthText len =
    case len of
        1 ->
            " [ 1 record ]"

        _ ->
            " [ " ++ (toString len) ++ " records ]"



{--
    Entry point for taking a WrappedJsonValue value, and rendering a tree structure with containers.

    This function takes a top level WrappedJsonVAlue, and renders recursively based on its type.
    The result is a tree like structure of arrays, dicts, and primitives, all return in type Html
--}


renderWrappedValue : WrappedJsonValue -> Html Msg
renderWrappedValue val =
    case val of
        WrappedValue primitive ->
            case primitive of
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

        WrappedSequence sequence ->
            -- If this value type is a sequence, it will have child values. Handle logic here
            -- to unpack and wrap rendered children content with containers
            case sequence of
                ArraySequence config list ->
                    -- If the container config is collapsed, don't bother traversing deeper and rendering anything
                    if config.collapsed then
                        -- If a previous check is determined this container of items is 'Tabular', call render
                        -- table function in RenderPanels.elm
                        createCollapseWrapper config (List.length list) "[]" []
                    else if config.tabular then
                        -- Render the table and wrap it with a container (including collapse button to show/hide)
                        [ renderListTable config list ]
                            |> createCollapseWrapper config (List.length list) "[]"
                    else
                        list
                            -- |> filterBy conf.filters
                            |> List.map (\item -> renderListElement item)
                            |> createCollapseWrapper config (List.length list) "[]"

                HashSequence config dict ->
                    let
                        keyValues =
                            Dict.toList dict
                    in
                        -- If the container config is collapsed, don't bother traversing deeper and rendering anything
                        if config.collapsed then
                            createCollapseWrapper config (List.length keyValues) "{}" []
                        else
                            -- For each key value item, render and wrap in container if child not primitive type
                            keyValues
                                |> List.map (\item -> renderDictElement item)
                                |> createCollapseWrapper config (List.length keyValues) "{}"



{--
    This function takes an element in a WrappedJsonList and renders with the according class.
    The item rendered here is a child of a parent WrappedJSONValue Sequence, and will be
    nested in a parent container.
--}


renderListElement : WrappedJsonValue -> Html Msg
renderListElement val =
    case val of
        WrappedValue _ ->
            span [ class "value array primitive" ]
                [ renderWrappedValue val -- Draw out the value, potentially recursing
                ]

        WrappedSequence _ ->
            div [ class "value array" ]
                [ renderWrappedValue val -- Draw out the value, potentially recursing
                ]



{--
    Similar to renderListElement but here the child element we are rendering is in a key value pair.
    This funciton renders the 'key' followed by ':', rendering the value by recursing back to
    renderWrappedValue, potentially making more containers/ key values.
--}


renderDictElement : ( String, WrappedJsonValue ) -> Html Msg
renderDictElement ( key, val ) =
    case val of
        WrappedValue _ ->
            div [ class "key-value-row" ]
                [ span [ class "key", title key ]
                    [ text (key ++ ":")
                    ]
                , span [ class "value" ]
                    -- Draw out the value, potentially recursing
                    [ renderWrappedValue val ]
                ]

        WrappedSequence _ ->
            div [ class "key-value-row pl-1 relative" ]
                [ span [ class "value object" ]
                    -- Draw out the value, potentially recursing
                    [ renderWrappedValue val ]
                ]



{--
    Given a sequence config and a list of pre rendered child elements, wrap them in a container
    and decide how many to show, or to show at all.

    Args
        config   (SequenceContainer)  The configuration container paired with the WrappedJsonValue we are rendering
        len      (Int)                The length of the sequence object we are rendering (lentgh of keys, or elements)
        brackets (String)             What type of sequence is this, a dict or array? Should we render {} or [] for visualization
        elms     (List (Html Msg))    A list of already rendered children elements this container is wrapping

    Returns
        A wrapping container potentially containing the items passed in, and elements holding
        functionality to collapse / page the items passed in
--}


createCollapseWrapper : SequenceContainer -> Int -> String -> List (Html Msg) -> Html Msg
createCollapseWrapper config len brackets elms =
    let
        {--
            Paging logic, math, and event configurations
        --}
        pages =
            ceiling <| (toFloat len) / (toFloat config.limit)

        currentPage =
            1 + (floor <| toFloat pages * (toFloat config.offset / toFloat len))

        showPagingControls =
            len <= config.limit || config.collapsed == True || brackets == "{}"

        -- Logic to determine if the paging controls should be rendered
        showWrappedContainerClass =
            if showPagingControls then
                ""
            else
                " show-border"

        {--
            How does each button change the config state?
        --}
        pagingButtonAction dir =
            case dir of
                "Beginning" ->
                    { config | offset = 0 }

                "Previous" ->
                    { config | offset = config.offset - config.limit }

                "Next" ->
                    { config | offset = config.offset + config.limit }

                "Last" ->
                    { config | offset = (len - config.limit) + 1 }

                _ ->
                    config

        {--
            Based on state, which button should be disabled?
        --}
        pagingButtonDisabled dir =
            case dir of
                "Back" ->
                    if currentPage == 1 then
                        "disabled"
                    else
                        ""

                "Forward" ->
                    if currentPage == pages then
                        "disabled"
                    else
                        ""

                _ ->
                    ""

        -- On dropdown select, set config limit int from string option
        getPagingSizeInt selected =
            case String.toInt selected of
                Ok v ->
                    v

                Err _ ->
                    1

        pagingControls =
            if showPagingControls then
                text ""
            else
                div [ class "tc f6" ]
                    [ button
                        [ class <| "paging-button btn mr button-transparent " ++ (pagingButtonDisabled "Back")
                        , onClick <| MutateSequenceContainer config (pagingButtonAction "Beginning")
                        ]
                        [ i [ class "fa fa-fw fa-angle-double-left" ] [] ]
                    , button
                        [ class <| "paging-button btn mr button-transparent " ++ (pagingButtonDisabled "Back")
                        , onClick <| MutateSequenceContainer config (pagingButtonAction "Previous")
                        ]
                        [ i [ class "fa fa-fw fa-angle-left" ] [] ]
                    , span [ class "page-current" ] [ text <| toString currentPage ]
                    , span [ class "paging-total" ] [ text <| "/ " ++ (toString pages) ]
                    , button
                        [ class <| "paging-button btn ml button-transparent " ++ (pagingButtonDisabled "Forward")
                        , onClick <| MutateSequenceContainer config (pagingButtonAction "Next")
                        ]
                        [ i [ class "fa fa-fw fa-angle-right" ] [] ]
                    , button
                        [ class <| "paging-button btn ml mr button-transparent " ++ (pagingButtonDisabled "Forward")
                        , onClick <| MutateSequenceContainer config (pagingButtonAction "Last")
                        ]
                        [ i [ class "fa fa-fw fa-angle-double-right" ] [] ]
                    , select
                        [ onInput (\v -> MutateSequenceContainer config { config | limit = getPagingSizeInt <| v })
                        ]
                        [ option [ value "100" ] [ text "100" ], option [ value "500" ] [ text "500" ], option [ value "1000" ] [ text "1000" ], option [ value "999999999" ] [ text "All" ] ]
                    ]

        {--
            Wrapper for elements, text label to show length of object, and collapse icon state
        --}
        content =
            if len == 0 then
                text ""
            else
                div [ class "wrapper-content" ]
                    elms

        collapsedStateIcon =
            if config.collapsed then
                "fa-caret-right"
            else
                "fa-caret-down"

        itemsLengthText =
            if brackets == "{}" then
                text <| "{" ++ (toString len) ++ "}"
            else
                text <| "[" ++ (toString len) ++ "]"
    in
        -- If this is the top level wrapper, and the array data is tabular, avoid rendering the wrapper padding
        if config.isTopLevelContainer && config.tabular then
            div []
                [ content
                , pagingControls
                ]
        else
            div [ class <| "collapse-wrapper" ++ showWrappedContainerClass ]
                [ span [ onClick <| MutateSequenceContainer config { config | collapsed = not config.collapsed } ]
                    [ i [ class <| "tree-collapse-action fa fa-fw " ++ collapsedStateIcon ] []
                    , span [ class "wrapper-key" ] [ text config.key ]
                    , span [ class "wrapper-length" ] [ itemsLengthText ]
                    ]
                , content
                , pagingControls
                ]
