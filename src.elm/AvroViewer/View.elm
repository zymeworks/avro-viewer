module AvroViewer.View exposing (detailsView, filesLengthText, loadingView, renderCollapseAllButton, renderDropZone, renderErrors, renderErrorsHeading, renderViewControls, topView, uploadView)

import AvroViewer.Model exposing (..)
import AvroViewer.RenderPanels exposing (..)
import AvroViewer.RenderTree exposing (..)
import Dict exposing (Dict)
import FileReader exposing (NativeFile)
import FileReader.FileDrop as DnD
import Html exposing (Html, a, button, div, form, h1, h2, h3, hr, i, img, input, nav, p, span, text, textarea)
import Html.Attributes exposing (action, class, href, id, method, multiple, placeholder, rows, style, target, title, type_)
import Html.Events exposing (on, onClick)
import Json.Decode as Decoder exposing (Decoder)



{--
    Top level view container that delegates view to rendering functions depending on state
--}


topView : Model -> Html Msg
topView model =
    div [ class "pa3" ]
        [ case model.page of
            UploadPage ->
                uploadView model

            LoadingPage ->
                loadingView model

            DetailsPage ->
                detailsView model
        ]



{--
    View renderer for UPLOAD state, drag and drop file container, file chooser, and title
--}


uploadView : Model -> Html Msg
uploadView model =
    div [ class "mw8 center pa4 pb6i" ]
        [ div [ class "group-panel" ]
            [ h2 [ class "group-title" ] [ text "Upload Avro or JSON Files" ]
            , renderDropZone model
            , hr [] []
            , div [ class "mb2" ] [ text "Or use the file picker below" ]
            , input
                [ type_ "file"
                , id fileInputID
                , class "f7-ns"
                , placeholder "Select AVRO or JSON files"
                , Html.Attributes.accept ".avro,.json"
                , on "change" (Decoder.succeed FileSelected)
                , multiple True
                ]
                []
            ]
        ]



{--
    View renderer for LOADING state, Loading text, and decoding progress status
--}


loadingView : Model -> Html Msg
loadingView model =
    let
        renderProgess p =
            div [ class "group-panel" ]
                [ h2 [ class "group-title" ] [ text p.filename ]
                , text (toString p.records ++ " records decoded")
                ]
    in
    div [ class "mw8 center pa4 pb6i pt1" ]
        [ h3 [ class "ph1 mb3" ] [ text "Decoding Files" ]
        , div [] (List.map renderProgess model.recordDecodingProgress)
        ]



{--
    View renderer for DETAILS state containing:
        Details header, view controls, error heading and errors container, data rendering based on view mode
--}


detailsView : Model -> Html Msg
detailsView model =
    let
        contents =
            -- Are we rendering tree view, or panel view?
            case model.viewMode of
                Tree ->
                    -- Pass List Record to tree renderer in RenderTree.elm
                    div [ class "tree-contents-container " ]
                        (List.map renderTreeView model.parsedRecords)

                Panel ->
                    -- Pass model to panel renderer in RenderPanels.elm
                    div [] [ renderPanelView model ]
    in
    div []
        [ div [ class "details-container" ]
            [ div [ class "details-header-group" ]
                [ div [ class "details-header" ]
                    [ div [ class "parsed-files-title" ] [ text <| filesLengthText model.parsedRecords ]
                    , button [ class "btn white bg-blue mb1 pa2 ph4 f6 mt1", onClick ToUpload ] [ text "Reset" ]
                    ]
                , renderErrorsHeading model
                , renderErrors model
                , renderViewControls model
                ]
            ]
        , contents
        ]



{--
    Render and handle highlighting styles for when user is dragging a file over the dropzone
--}


renderDropZone : Model -> Html Msg
renderDropZone model =
    let
        dzAttrs_ =
            DnD.dzAttrs (OnDragEnter True) (OnDragEnter False) NoOp OnDrop

        dzClass =
            if model.dragHovering == True then
                id "drop-zone" :: class "dropzone hover" :: dzAttrs_

            else
                id "drop-zone" :: class "dropzone" :: dzAttrs_
    in
    div dzClass [ text "Drag and Drop Avro or JSON files here" ]



{--
    Render container of view mode icons and handle controls for changing view mode.
    Highlight and draw if Tree view or Panel view are selected.
--}


renderViewControls : Model -> Html Msg
renderViewControls model =
    let
        treeActive =
            case model.viewMode of
                Tree ->
                    "active"

                Panel ->
                    ""

        panelActive =
            case model.viewMode of
                Tree ->
                    ""

                Panel ->
                    "active"
    in
    div [ class "view-controls" ]
        [ div
            [ class <| "control-container " ++ treeActive
            , onClick <| SetViewMode Tree
            ]
            [ i [ class "fa fa-list" ] []
            , span [ class "info-bubble" ] [ text "Tree View" ]
            ]
        , div
            [ class <| "control-container " ++ panelActive
            , onClick <| SetViewMode Panel
            ]
            [ i [ class "fa fa-columns" ] []
            , span [ class "info-bubble" ] [ text "Panel View" ]
            ]
        , renderCollapseAllButton model

        -- , div
        --     [ class <| "control-container "
        --     , onClick <| SetViewMode Panel
        --     ]
        --     [ i [ class "fa fa-map-pin" ] []
        --     , span [ class "info-bubble" ] [ text "Pinned Items" ]
        --     ]
        ]



{--
    Render/handle Collapse all/expand all records button in top area of the details view
--}


renderCollapseAllButton : Model -> Html Msg
renderCollapseAllButton model =
    let
        allCollapsed =
            let
                filtered =
                    model.parsedRecords
                        |> List.filter (\p -> p.expanded)
                        |> List.length
            in
            filtered == 0

        icon =
            if allCollapsed then
                "mr2 expand-icon fa fa-plus-square-o"

            else
                "mr2 expand-icon fa fa-minus-square-o"

        buttonLabel =
            if allCollapsed then
                "Expand All"

            else
                "Collapse All"
    in
    case model.viewMode of
        Tree ->
            if List.length model.parsedRecords > 0 then
                button [ class "btn btn-transparent mr3 ml2 mb1", onClick <| ToggleAllCollapseContainer allCollapsed ]
                    [ i [ class icon ] []
                    , span [] [ text buttonLabel ]
                    ]

            else
                text ""

        Panel ->
            text ""


filesLengthText : List Record -> String
filesLengthText files =
    case files of
        [] ->
            "No Files Parsed"

        [ _ ] ->
            "Parsed 1 File"

        _ :: _ ->
            "Parsed " ++ (toString <| List.length files) ++ " Files"



{--
    Render the error banner, container the number of errors, and the collapse/expand button
--}


renderErrorsHeading : Model -> Html Msg
renderErrorsHeading model =
    let
        length =
            model.parseErrors
                |> List.length
                |> toString

        errorPlural =
            if List.length model.parseErrors == 1 then
                " error"

            else
                " errors"

        showOrHideErrorsLabel =
            if model.hideErrors then
                "Show errors"

            else
                "Hide errors"
    in
    case model.parseErrors of
        [] ->
            text ""

        _ ->
            div [ class "errors-header" ]
                [ i [ class "fa fa-exclamation-triangle" ] []
                , span [] [ text <| "With " ++ length ++ errorPlural ]
                , div [] [ span [ class "errors-show-hide", onClick ToggleShowErrors ] [ text showOrHideErrorsLabel ] ]
                ]



{--
    Render the actual list of error messages/containers, shown at the top of the page
--}


renderErrors : Model -> Html Msg
renderErrors model =
    let
        renderErrorContainer error =
            div [ class "error-container" ]
                [ div [ class "error-container-icon" ]
                    [ i [ class "fa fa-exclamation-triangle" ] []
                    ]
                , div [ class "error-contents" ]
                    [ div []
                        [ span [ class "error-label" ] [ text "File:" ]
                        , span [ class "error-details" ] [ text error.filename ]
                        ]
                    , div []
                        [ span [ class "error-label" ] [ text "Error:" ]
                        , span [ class "error-details" ] [ text error.message ]
                        ]
                    ]
                ]
    in
    if List.length model.parseErrors == 0 || model.hideErrors then
        text ""

    else
        div [ class "errors-group" ]
            [ div [] <|
                List.map renderErrorContainer model.parseErrors
            ]
