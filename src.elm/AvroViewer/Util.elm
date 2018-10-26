module AvroViewer.Util exposing (..)

import AvroViewer.Model exposing (..)
import AvroViewer.JsonParse as JParse
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline as JP
import Dict exposing (..)


{--
    Parse JSON results from file parse task and map to a list of records (filename, contents, etc) for our model

    Args:
        stringifiedResults: String  - JSON stringified list results from our main.js, meta data included alongside our actual data

    Returns:
        List Record : A list of mapped records for our model, with the new record correctly added to the right record and entry
--}


ingestResults : String -> List Record
ingestResults stringifiedResults =
    Decode.decodeString parsedFilePayloadDecoder stringifiedResults |> Result.withDefault []


parsedFilePayloadDecoder : Decoder (List Record)
parsedFilePayloadDecoder =
    let
        fileResultRecordDecoder : String -> String -> Int -> Bool -> Int -> Decoder Record
        fileResultRecordDecoder filename dataString numRecords limitReached index =
            let
                -- Convert the stringified JSON to our WrappedJSONValue type
                parsed =
                    JParse.parseJson dataString

                newRecord =
                    { filename = filename
                    , index = index
                    , contents =
                        JParse.indexWrappedJson
                            parsed
                            { defaultContainer
                                | path = [ File filename ]
                            }
                    , count = numRecords
                    , expanded = True
                    , recordLimitReached = limitReached
                    }
            in
                Decode.succeed newRecord
    in
        Decode.list <|
            (JP.decode fileResultRecordDecoder
                |> JP.required "filename" Decode.string
                |> JP.required "data" Decode.string
                |> JP.required "count" Decode.int
                |> JP.required "limitReached" Decode.bool
                |> JP.required "index" Decode.int
                |> JP.resolve
            )



{--
    Parse JSON errors from file parse task and map to our error model

    Args:
        stringifiedErrors: String  - JSON stringified list of errors from our main.js

    Returns:
        List FileError : mapped errors for our view model
--}


ingestErrors : String -> List FileError
ingestErrors stringifiedErrors =
    Decode.decodeString parseFileErrorDecoder stringifiedErrors |> Result.withDefault []


parseFileErrorDecoder : Decoder (List FileError)
parseFileErrorDecoder =
    let
        fileErrorRecordDecoder : String -> String -> Decoder FileError
        fileErrorRecordDecoder filename errorMessage =
            Decode.succeed (FileError errorMessage filename)
    in
        Decode.list <|
            (JP.decode fileErrorRecordDecoder
                |> JP.required "filename" Decode.string
                |> JP.required "message" Decode.string
                |> JP.resolve
            )



{--
    Helper function to take a Maybe PathPartial and render it as a string.
    This function is used in Indexing and printing the path to an element.
--}


pathPartialToString : Maybe PathPartial -> String
pathPartialToString item =
    case item of
        Just partial ->
            case partial of
                Key val ->
                    val

                File val ->
                    val

                Index _ ->
                    ""

        Nothing ->
            ""



{--
    Helper function to take a Maybe PathPartial and render it as an Index.
    This function is used in Indexing and printing the path to an element.
--}


pathPartialToInt : Maybe PathPartial -> Int
pathPartialToInt item =
    case item of
        Just partial ->
            case partial of
                Key val ->
                    -1

                File val ->
                    -1

                Index ind ->
                    ind

        Nothing ->
            -1



{--
    Get an item in a list by index. This is used when traversing a tree given a path,
    and the path contains Indices to specific elements in a Sequence Array
--}


getByIndex : Int -> List a -> Maybe a
getByIndex index list =
    if index >= (List.length list) then
        Nothing
    else
        List.take (index + 1) list
            |> List.reverse
            |> List.head



{--
    This function takes the top level model of records, a path, and traverses
    until the target subtree is found.

    Args
        files       (List Record)       List of records in our top level model, contains Sequence Array of datum
        fullpath    (List PathPartial)  The full path of Partials we need to traverse to find the target value

    Returns
        The WrappedJsonValue at the end of the path specified
--}


getSubtree : List Record -> List PathPartial -> WrappedJsonValue
getSubtree files fullpath =
    let
        -- Deconstructing path list
        pathHead p =
            List.head p

        pathTail p =
            p
                |> List.tail
                |> Maybe.withDefault []

        -- Through the list of records, find the record with given filename
        findFileByName fname =
            files
                |> List.filter (\r -> r.filename == fname)
                |> List.head

        {--
            Here is the recursive function to traverse the tree following our path.
            Now we can recurse through the values because we found the target file,
            and dropped the first PathPartial (of type File). As of this point, we
            are only dealing PathPartials of Key or Index, which are only relevent
            with WrappedJsonValue.
        --}
        foldTree : WrappedJsonValue -> List PathPartial -> WrappedJsonValue
        foldTree tree remainingPath =
            case pathHead remainingPath of
                Just p ->
                    case p of
                        File n ->
                            -- This case should not happen, only the first element in the
                            -- path can be a file partial, and at this point we have tail
                            tree

                        Index ind ->
                            case tree of
                                -- If the next path is an index, the type of tree must be ArraySequence
                                WrappedValue _ ->
                                    tree

                                WrappedSequence seq ->
                                    case seq of
                                        ArraySequence config list ->
                                            case getByIndex ind list of
                                                Just el ->
                                                    foldTree el (pathTail remainingPath)

                                                Nothing ->
                                                    tree

                                        HashSequence config dict ->
                                            tree

                        Key key ->
                            -- If the next path is a key, the type of tree must be HashSequence
                            case tree of
                                WrappedValue _ ->
                                    tree

                                WrappedSequence seq ->
                                    case seq of
                                        ArraySequence config list ->
                                            tree

                                        HashSequence config dict ->
                                            case Dict.get key dict of
                                                Just el ->
                                                    foldTree el (pathTail remainingPath)

                                                Nothing ->
                                                    tree

                Nothing ->
                    tree
    in
        -- Initial case of path HAS to be a file name, other cases will not be valid
        -- Just scope to the specified file and then traverse the tree with foldTree
        case pathHead fullpath of
            Just p ->
                case p of
                    File val ->
                        -- Find file in list
                        case findFileByName val of
                            Just record ->
                                foldTree record.contents (pathTail fullpath)

                            Nothing ->
                                WrappedValue JsNull

                    Key val ->
                        WrappedValue JsNull

                    Index _ ->
                        WrappedValue JsNull

            Nothing ->
                WrappedValue JsNull



{--
    Given a top level wrapped json value, determine if it is ArraySequence type,
    and if the configuartion was already set as tabular, return the list.
--}


dataIfTabular : WrappedJsonValue -> Maybe (List WrappedJsonValue)
dataIfTabular val =
    case val of
        WrappedValue _ ->
            Nothing

        WrappedSequence s ->
            case s of
                ArraySequence config l ->
                    if config.tabular then
                        Just l
                    else
                        Nothing

                HashSequence _ _ ->
                    Nothing



{--
    Check the sequence configuration of a given value and return its 'tabular' property
--}


nodeIsTabular : WrappedJsonValue -> Bool
nodeIsTabular val =
    case val of
        WrappedValue _ ->
            False

        WrappedSequence s ->
            case s of
                ArraySequence config _ ->
                    config.tabular

                HashSequence config _ ->
                    config.tabular



{--
    Given a top level wrapped json value, determine if it is ArraySequence type,
    and if the configuartion was already set as tabular, return the list.
--}


rollupAllContainers : Bool -> WrappedJsonValue -> WrappedJsonValue
rollupAllContainers collapsed node =
    case node of
        WrappedValue _ ->
            node

        WrappedSequence seq ->
            case seq of
                ArraySequence config list ->
                    let
                        mappedItems =
                            List.map (\i -> rollupAllContainers collapsed i) list
                    in
                        -- Collapse doesnt apply to top level tables
                        if config.isTopLevelContainer && config.tabular then
                            WrappedSequence seq
                        else
                            WrappedSequence (ArraySequence { config | collapsed = collapsed } mappedItems)

                HashSequence config dict ->
                    let
                        mapDict ( key, value ) =
                            ( key, (rollupAllContainers collapsed value) )

                        mappedItems =
                            dict
                                |> Dict.toList
                                |> List.map mapDict
                                |> Dict.fromList
                    in
                        WrappedSequence (HashSequence { config | collapsed = collapsed } mappedItems)
