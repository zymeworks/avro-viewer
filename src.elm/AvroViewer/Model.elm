module AvroViewer.Model exposing (..)

import AvroViewer.Port exposing (..)
import FileReader exposing (NativeFile)
import Json.Decode exposing (..)
import Dict exposing (Dict)


fileInputID : String
fileInputID =
    "avro-file-input"


panelContainerID : String
panelContainerID =
    "panelContainer"


tableKeyPriority : String
tableKeyPriority =
    "Optional-Default-Sort-Key"


type alias Model =
    { page : Page
    , viewMode : ViewMode
    , panelPath : List PathPartial
    , dragHovering : Bool
    , recordDecodingProgress : List DecodingProgress
    , parsedRecords : List Record
    , generatedTable : Maybe (List WrappedJsonValue)
    , parseErrors : List FileError
    , hideErrors : Bool
    }



--App Message Events


type Msg
    = ToUpload
    | FileSelected
    | FileReadProgress ( Int, String, Int )
    | FileResults ( String, String )
    | OnDragEnter Bool
    | OnDrop (List NativeFile)
    | MutateSequenceContainer SequenceContainer SequenceContainer
    | SetViewMode ViewMode
    | SetPanelPath (List PathPartial)
    | ExpandFileRow Record
    | ToggleAllCollapseContainer Bool
    | ToggleShowErrors
    | DownloadAsJson Record
    | DownloadLocalCSV (List WrappedJsonValue)
    | NoOp



--Current Page State


type Page
    = UploadPage
    | LoadingPage
    | DetailsPage


type ViewMode
    = Tree
    | Panel



-- Decoding progress state


type alias DecodingProgress =
    { filename : String
    , index : Int
    , records : Int
    }


type alias FileError =
    { message : String
    , filename : String
    }



-- File container wrapping data/contents


type alias Record =
    { filename : String
    , index : Int
    , contents : WrappedJsonValue
    , count : Int
    , recordLimitReached : Bool
    , expanded : Bool
    }



-- Types, Config, and Wrapper for decoded values


type alias SequenceContainer =
    { collapsed : Bool
    , limit : Int
    , offset : Int
    , key : String
    , isTopLevelContainer : Bool
    , path : List PathPartial
    , tabular : Bool
    , tableRowCollapsed : Bool
    }


defaultContainer =
    { collapsed = False
    , limit = 100
    , offset = 0
    , key = ""
    , path = []
    , isTopLevelContainer = False
    , tabular = False
    , tableRowCollapsed = True
    }


type PathPartial
    = Key String
    | Index Int
    | File String


type Sequence
    = ArraySequence SequenceContainer (List WrappedJsonValue)
    | HashSequence SequenceContainer (Dict String WrappedJsonValue)


type WrappedJsonValue
    = WrappedValue JsonValue
    | WrappedSequence Sequence


type JsonValue
    = JsBool Bool
    | JsString String
    | JsInt Int
    | JsFloat Float
    | JsNull
