module AvroViewer.JsonMutate exposing (..)

import AvroViewer.Model exposing (..)
import AvroViewer.Util as Util
import Json.Decode as Decode exposing (Decoder)
import Dict exposing (Dict)


{--
    Traverse through the wrapped json value, which is a tree containing the actual
    sequence container we need to toggle, continue to traverse down the path,
    dropping and path partials as we search deeper

    The first step is to iterate over each parsed file, the first part of path config is the filename of the
    file in the parsedRecords list

    To find and change Sequence Container, we need to traverse through the only entry
    point in model.

        []               Tree [index]              Config
        parsedRecords -> WrappedJsonValue Array -> Container
--}


mapRecordsForMutate : Record -> List PathPartial -> SequenceContainer -> Record
mapRecordsForMutate record path newConfig =
    let
        filename =
            Util.pathPartialToString <| List.head path

        remainder =
            List.drop 1 path
    in
        if record.filename == filename then
            { record
                | contents =
                    findAndReplaceContainer record.contents remainder newConfig
            }
        else
            record



{--
    Finally, the last step is to traverse the WrappedJsonValue tree to find the target
    container based on the provided path array.

    Args
        value       (WrappedJsonValue)      The current item being traversed in the tree
        path        (List PathPartial)      The path up to this point (sum of parents identifiers)
        newConfig   (SequenceContainer)     The new path the child subsequently called should be assigned

    Returns
        The same WrappedJsonValue, but if there value is a sequence then it is replaced with a new config
        indexed with a path
--}


findAndReplaceContainer : WrappedJsonValue -> List PathPartial -> SequenceContainer -> WrappedJsonValue
findAndReplaceContainer value path newConfig =
    let
        -- If the current path partial is for sure an index, we traverse the array here now
        traverseArray : List PathPartial -> Int -> WrappedJsonValue -> WrappedJsonValue
        traverseArray remainingPath index value =
            let
                targetIndex =
                    Util.pathPartialToInt <| List.head remainingPath

                remainder =
                    List.drop 1 remainingPath
            in
                if targetIndex == index then
                    -- If remainder here is empty, the next call will take care of toggling the container
                    findAndReplaceContainer value remainder newConfig
                else
                    value

        -- If the current path partial is a key, we traverse the key value pairs here now
        traverseDict : List PathPartial -> ( String, WrappedJsonValue ) -> ( String, WrappedJsonValue )
        traverseDict remainingPath ( key, value ) =
            let
                targetKey =
                    Util.pathPartialToString <| List.head remainingPath

                remainder =
                    List.drop 1 remainingPath
            in
                if targetKey == key then
                    -- If remainder here is empty, the next call will take care of toggling the container
                    ( key, findAndReplaceContainer value remainder newConfig )
                else
                    ( key, value )
    in
        case value of
            WrappedValue primitive ->
                WrappedValue primitive

            WrappedSequence sequence ->
                let
                    updatedSequence =
                        case sequence of
                            ArraySequence config list ->
                                let
                                    targetIndex =
                                        Util.pathPartialToInt <| List.head path
                                in
                                    if List.length path == 0 then
                                        -- End of the path, this must be the config to update
                                        ArraySequence newConfig list
                                    else if targetIndex == -1 then
                                        -- If the current path partial is not an indix for an array, just pass the value and move on
                                        ArraySequence config list
                                    else
                                        -- Else we are stilling traversing down the path, iterate search and recurse
                                        List.indexedMap (\el -> traverseArray path el) list
                                            |> ArraySequence config

                            HashSequence config dict ->
                                let
                                    targetKey =
                                        Util.pathPartialToString <| List.head path
                                in
                                    if List.length path == 0 then
                                        -- End of the path, this must be the config to update
                                        HashSequence newConfig dict
                                    else if targetKey == "" then
                                        -- If the current path partial is not a key for a dict, just pass the value and move on
                                        HashSequence config dict
                                    else
                                        -- Else we are stilling traversing down the path, iterate search and recurse
                                        dict
                                            |> Dict.toList
                                            |> List.map (\pair -> traverseDict path pair)
                                            |> Dict.fromList
                                            |> HashSequence config
                in
                    WrappedSequence updatedSequence
