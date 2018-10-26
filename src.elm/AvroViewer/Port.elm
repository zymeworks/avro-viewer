port module AvroViewer.Port exposing (..)

import FileReader exposing (NativeFile)


type alias FileData =
    { contents : Maybe String
    , index : Maybe Int
    , filename : String
    , filetype : String
    }



-- to JS


port fileDecodeProgress : (( Int, String, Int ) -> msg) -> Sub msg


port fileParseResults : (( String, String ) -> msg) -> Sub msg



-- From JS


port fileSelected : String -> Cmd msg


port fileSave : FileData -> Cmd msg


port scrollPanelViewRight : String -> Cmd msg
