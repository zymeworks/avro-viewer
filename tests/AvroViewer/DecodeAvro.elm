module AvroViewer.DecodeAvro exposing (..)

import AvroViewer.Util as Util
import AvroViewer.Model exposing (..)
import AvroViewer.JsonParse as JParse
import Test exposing (..)
import Expect
import Dict exposing (..)


testValue =
    let
        primitiveInt =
            WrappedValue <| JsInt 0

        primitiveString =
            WrappedValue <| JsString "abc"

        config =
            { defaultContainer | path = [ File "test.avro" ] }

        testDict =
            Dict.fromList [ ( "int", primitiveInt ), ( "testString", primitiveString ) ]
    in
        WrappedSequence <|
            HashSequence config testDict


testRecord =
    { filename = "test.avro"
    , contents = testValue
    , expanded = False
    , index = 0
    , count = 0
    , recordLimitReached = False
    }



{--
    Given an already parsed avro file (unformatted JSON), ensure our decoder reads it in and parses properly.

    Input:
        "{test: 0, test2: 'a'}"

    Output:
        WrappedJsonValue ArraySequence Config List
            list.length 1
                type of list
                    HashSequence
                        Dict to list length 2
--}


testElmDecodeWrappedJsonValue : Test
testElmDecodeWrappedJsonValue =
    let
        records =
            []

        input =
            "[{\"filename\":\"test.avro\",\"index\":0,\"count\":0,\"limitReached\":false,\"data\":\"{\\\"int\\\": 0,\\\"testString\\\":\\\"abc\\\"}\"}]"

        getFirstRecord : List Record -> WrappedJsonValue
        getFirstRecord list =
            case List.head list of
                Just r ->
                    r.contents

                Nothing ->
                    WrappedValue JsNull
    in
        describe "JParse.toWrappedJson"
            [ test "Decodes JSON string as WrappedJsonValue with entry added as Hash Sequence" <|
                \_ ->
                    Util.ingestResults input
                        |> getFirstRecord
                        |> Expect.equal testValue
            ]



-- Get subtree


testTreeTraversal : Test
testTreeTraversal =
    let
        pathToRender =
            [ File "test.avro", Key "testString" ]

        subtree =
            Util.getSubtree [ testRecord ] pathToRender
    in
        describe "Util.getSubtree"
            [ test "With a root WrappedJsonValue, ensure tree can be traversed and data can be retrieved" <|
                \_ ->
                    Expect.equal (WrappedValue <| JsString "abc") subtree
            ]



-- Export panel as csv


testSubtreeCSVExport : Test
testSubtreeCSVExport =
    let
        input =
            "[{\"filename\":\"test.avro\",\"index\":0,\"count\":0,\"limitReached\":false,\"data\":\"[{\\\"id\\\":1,\\\"name\\\":\\\"a\\\"},{\\\"id\\\":2,\\\"name\\\":\\\"b\\\"},{\\\"id\\\":3,\\\"name\\\":\\\"c\\\"}]\"}]"

        output =
            "id,name\n1,\"a\"\n2,\"b\"\n3,\"c\""

        decodedAndParsed =
            Util.ingestResults input

        subtree =
            Util.getSubtree decodedAndParsed [ File "test.avro" ]

        extractedArrayFromSequence =
            case subtree of
                WrappedValue _ ->
                    []

                WrappedSequence s ->
                    case s of
                        ArraySequence config l ->
                            if config.tabular then
                                l
                            else
                                []

                        HashSequence _ _ ->
                            []
    in
        describe "JParse.exportCSVSubTree"
            [ test "Decodes JSON string as WrappedJsonValue with entry added as ArraySequence" <|
                \_ ->
                    Expect.equal output (JParse.exportCSVSubTree extractedArrayFromSequence)
            ]
