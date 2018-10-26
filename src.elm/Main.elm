module Main exposing (..)

import AvroViewer.View exposing (..)
import AvroViewer.Model exposing (..)
import AvroViewer.Port exposing (..)
import AvroViewer.JsonParse as JParse
import AvroViewer.JsonMutate as JMutate
import AvroViewer.Util as Util
import FileReader.FileDrop as DnD
import Platform exposing (Program)
import Html


init : ( Model, Cmd Msg )
init =
    ( { page = UploadPage
      , viewMode = Tree
      , panelPath = []
      , dragHovering = False
      , recordDecodingProgress = []
      , parsedRecords = []
      , generatedTable = Nothing
      , parseErrors = []
      , hideErrors = False
      }
    , Cmd.none
    )


updateDecodeProgress : List DecodingProgress -> Int -> String -> Int -> List DecodingProgress
updateDecodeProgress progressContainers index fname recordCount =
    let
        found =
            progressContainers
                |> List.filter (\r -> r.index == index)
                |> List.head
    in
        case found of
            Just f ->
                progressContainers
                    |> List.map
                        (\c ->
                            if f == c then
                                { c | records = recordCount }
                            else
                                c
                        )

            Nothing ->
                List.append progressContainers [ (DecodingProgress fname index recordCount) ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        -- Handle drag over event to show container dropzone style
        OnDragEnter hover ->
            ( { model | dragHovering = hover }, Cmd.none )

        -- Handle drop event (not parsing yet) and reset container styles/hover state, move to loading page
        OnDrop _ ->
            ( { model | page = LoadingPage }, Cmd.none )

        -- Handler for <input> file select
        FileSelected ->
            ( { model | page = LoadingPage }
            , fileSelected fileInputID
            )

        FileReadProgress ( index, fname, recordCount ) ->
            ( { model
                | page = LoadingPage
                , recordDecodingProgress = updateDecodeProgress model.recordDecodingProgress index fname recordCount
              }
            , Cmd.none
            )

        -- Callback from main.js when a file is decoded and passed along
        -- This function is called through a port and contains the entire decoded json data.
        -- This callback will happen once for each file.
        FileResults ( fileResults, fileErrors ) ->
            -- ingestResults, map errors
            ( { model
                | page = DetailsPage
                , dragHovering = False
                , parsedRecords = Util.ingestResults fileResults
                , parseErrors = Util.ingestErrors fileErrors
              }
            , Cmd.none
            )

        -- In panel view, each file, array, and dict has an onclick event to set the top level panel path [],
        -- This path is split and each element is rendered as a panel. This is the handler to set that
        SetPanelPath path ->
            ( { model
                | panelPath = path
              }
            , scrollPanelViewRight panelContainerID
              -- Port to main.js to scroll the panel container to the far right (when new panel opens)
            )

        -- Given a sequence container config, find it in the model/tree and 'update' it
        MutateSequenceContainer targetConfig newConfig ->
            ( { model
                | parsedRecords = List.map (\r -> JMutate.mapRecordsForMutate r targetConfig.path newConfig) model.parsedRecords
              }
            , Cmd.none
            )

        -- Expand / Collapse a file container in tree view
        ExpandFileRow record ->
            let
                findAndToggle row =
                    if row == record then
                        { row | expanded = not row.expanded }
                    else
                        row
            in
                ( { model | parsedRecords = List.map findAndToggle model.parsedRecords }, Cmd.none )

        -- Expand / Collapse every file container in tree view
        ToggleAllCollapseContainer expandAll ->
            let
                toggleAll row =
                    { row
                        | expanded = expandAll
                        , contents = Util.rollupAllContainers (not expandAll) row.contents
                    }
            in
                ( { model | parsedRecords = List.map toggleAll model.parsedRecords }, Cmd.none )

        -- Toggle collapse for the top level error container
        ToggleShowErrors ->
            ( { model
                | hideErrors = not model.hideErrors
              }
            , Cmd.none
            )

        -- Change the view mode to render the data (Tree view / Panel view)
        SetViewMode view ->
            ( { model
                | viewMode = view
              }
            , Cmd.none
            )

        -- On button click, reset state and return to upload page
        ToUpload ->
            ( { model
                | page = UploadPage
                , recordDecodingProgress = []
                , parsedRecords = []
                , parseErrors = []
                , hideErrors = False
                , viewMode = Tree
                , panelPath = []
              }
            , Cmd.none
            )

        -- Take any record (with potentially multiple entries) and port to main.js to export file
        DownloadAsJson record ->
            ( model
            , fileSave { filename = record.filename, index = Just record.index, contents = Nothing, filetype = "json" }
            )

        -- Given a subtree guaranteed to be type ArraySequence, convert to csv string and port to main.js to export file
        DownloadLocalCSV list ->
            ( model
            , fileSave { filename = "exported", index = Nothing, contents = Just (JParse.exportCSVSubTree list), filetype = "csv" }
            )

        _ ->
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ fileParseResults FileResults
        , fileDecodeProgress FileReadProgress
        ]


main : Program Never Model Msg
main =
    Html.program
        { init = init
        , view = topView
        , update = update
        , subscriptions = subscriptions
        }
