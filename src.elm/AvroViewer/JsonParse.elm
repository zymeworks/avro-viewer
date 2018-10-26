module AvroViewer.JsonParse exposing (..)

import AvroViewer.Model exposing (..)
import Json.Decode as Decode exposing (Decoder)
import Dict exposing (Dict)


parseJson : String -> WrappedJsonValue
parseJson data =
    Decode.decodeString jsonDecoder data |> Result.withDefault (WrappedValue JsNull)



{--
    Elm decoder utilizing the build in elm json decoder.
    This decoder lazily and recursively decodes a string of json into our custom WrappedJson type
--}


jsonDecoder : Decoder WrappedJsonValue
jsonDecoder =
    Decode.oneOf
        [ Decode.map (\v -> WrappedValue (JsString v)) Decode.string
        , Decode.map (\v -> WrappedValue (JsBool v)) Decode.bool
        , Decode.map (\v -> WrappedValue (JsInt v)) Decode.int
        , Decode.map (\v -> WrappedValue (JsFloat v)) Decode.float
        , Decode.list (Decode.lazy (\_ -> jsonDecoder))
            |> Decode.map (\v -> WrappedSequence (ArraySequence defaultContainer v))
        , Decode.dict (Decode.lazy (\_ -> jsonDecoder))
            |> Decode.map (\v -> WrappedSequence (HashSequence defaultContainer v))
        , Decode.null (WrappedValue JsNull)
        ]



{--
    Traverse through the wrapped json tree, indexing each container with a unique path
    This function sets all of the properties needed for each container in the tree.
    The container is responsible for holding a path to that node, handling collapse functionality,
    And keeping tack of the node's ability to show tabular data
--}


indexWrappedJson : WrappedJsonValue -> SequenceContainer -> WrappedJsonValue
indexWrappedJson value container =
    let
        -- Update sequence container with traversed path including new index and recurse
        indexArray : SequenceContainer -> Int -> WrappedJsonValue -> WrappedJsonValue
        indexArray config index value =
            let
                arrayIndexedConfig =
                    { config
                        | path = List.append config.path [ Index index ]
                        , key = ""
                    }
            in
                indexWrappedJson value arrayIndexedConfig

        -- Update sequence container with traversed path including new key and recurse
        indexDict : SequenceContainer -> ( String, WrappedJsonValue ) -> ( String, WrappedJsonValue )
        indexDict config ( key, value ) =
            let
                keyIndexedConfig =
                    { config
                        | path = List.append config.path [ Key key ]
                        , key = key
                    }
            in
                ( key, indexWrappedJson value keyIndexedConfig )
    in
        case value of
            WrappedValue primitive ->
                WrappedValue primitive

            -- If the current item we are indexing is a sequence, we need to iterate each of
            -- its children and index them as well. Use this parent sequence to key the children
            WrappedSequence sequence ->
                let
                    indexedSequence =
                        case sequence of
                            ArraySequence config list ->
                                let
                                    indexedConfig =
                                        { config
                                            | path = List.append config.path container.path
                                            , key = container.key
                                            , tabular = determineTabular list
                                            , isTopLevelContainer = True
                                        }
                                in
                                    List.indexedMap (\el -> indexArray indexedConfig el) list
                                        |> ArraySequence indexedConfig

                            HashSequence config dict ->
                                let
                                    indexedConfig =
                                        { config
                                            | path = List.append config.path container.path
                                            , key = container.key
                                        }
                                in
                                    dict
                                        |> Dict.toList
                                        |> List.map (\pair -> indexDict indexedConfig pair)
                                        |> Dict.fromList
                                        |> HashSequence indexedConfig
                in
                    WrappedSequence indexedSequence



{--
    Determine tabular
    This function traverses each element of the tree one level deep to check
    if the container/node's data is flat enough to produce a sensible table
--}


determineTabular : List WrappedJsonValue -> Bool
determineTabular value =
    let
        isPrimitive ( key, value ) =
            case value of
                WrappedValue primitive ->
                    True

                WrappedSequence sequence ->
                    False

        isTabular element =
            case element of
                WrappedValue primitive ->
                    False

                WrappedSequence sequence ->
                    case sequence of
                        ArraySequence config list ->
                            False

                        HashSequence config dict ->
                            dict
                                |> Dict.toList
                                |> List.all isPrimitive
    in
        -- Array is tabular only if every element in the list is primitive
        List.all isTabular value



{--
    Takes a Sequence with a container flagged as tabular, and print its key values in CSV format

    Args
        valueList (List WrappedJsonValue)   Child list of an Array Sequence where each item in the list
                                            is a Dict with only primitive key value pairs
    Returns
        csv (String)
--}


exportCSVSubTree : List WrappedJsonValue -> String
exportCSVSubTree valueList =
    let
        -- Take a WrappedJson value that is for sure a HashSequence dict and
        -- convert its key values to a List (key, value)
        unpactDict : WrappedJsonValue -> List ( String, WrappedJsonValue )
        unpactDict val =
            case val of
                WrappedValue primitive ->
                    []

                WrappedSequence sequence ->
                    case sequence of
                        ArraySequence config list ->
                            []

                        HashSequence config dict ->
                            dict
                                |> Dict.toList

        -- Print first row of comma separated keys
        mapHeaderKeys : Maybe WrappedJsonValue -> String
        mapHeaderKeys firstElement =
            case firstElement of
                Just el ->
                    el
                        |> unpactDict
                        |> List.map Tuple.first
                        |> concatAndJoinCommas

                Nothing ->
                    ""

        -- Print each value of a WrappedJsonValue dict
        mapListValues : WrappedJsonValue -> String
        mapListValues item =
            let
                --Print primitive
                printValuePrimitive value =
                    case value of
                        WrappedValue primitive ->
                            case primitive of
                                JsBool value ->
                                    toString value

                                JsString value ->
                                    toString value

                                JsInt value ->
                                    toString value

                                JsFloat value ->
                                    toString value

                                JsNull ->
                                    "Null"

                        WrappedSequence sequence ->
                            ""
            in
                item
                    |> unpactDict
                    |> List.map Tuple.second
                    |> List.map printValuePrimitive
                    |> concatAndJoinCommas

        -- Take a list of strings, insert "," between each element, and concat all
        concatAndJoinCommas : List String -> String
        concatAndJoinCommas items =
            items
                |> List.intersperse ","
                |> List.foldr (++) ""

        -- Take a list of rows (String), insert "\n" between each element, and concat all
        concatAndJoinRows rows =
            rows
                |> List.intersperse "\n"
                |> List.foldr (++) ""
    in
        (mapHeaderKeys (List.head valueList))
            ++ "\n"
            ++ (concatAndJoinRows (List.map mapListValues valueList))
