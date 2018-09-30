module Tests exposing (all, expectErr, isError, runWith)

import Expect exposing (Expectation)
import Json.Decode as Decode exposing (Decoder, null, string, succeed)
import Json.Decode.Extra
    exposing
        ( default
        , defaultAt
        , require
        , requireAt
        )
import Test exposing (..)


{-| Run some JSON through a Decoder and return the result.
-}
runWith : String -> Decoder a -> Result String a
runWith str decoder =
    Decode.decodeString decoder str
        |> Result.mapError Decode.errorToString


isError : Result err ok -> Bool
isError result =
    case result of
        Err _ ->
            True

        Ok _ ->
            False


expectErr : Result err ok -> Expectation
expectErr result =
    isError result
        |> Expect.true ("Expected an Err but got " ++ Debug.toString result)


all : Test
all =
    describe
        "Json.Decode.Pipeline"
        [ test "should decode basic example" <|
            \() ->
                (require string "a" <|
                    \a ->
                        require string "b" <|
                            \b ->
                                succeed ( a, b )
                )
                    |> runWith """{"a":"foo","b":"bar"}"""
                    |> Expect.equal (Ok ( "foo", "bar" ))
        , test "should decode requireAt fields" <|
            \() ->
                (requireAt string [ "a" ] <|
                    \a ->
                        requireAt string [ "b", "c" ] <|
                            \b ->
                                succeed ( a, b )
                )
                    |> runWith """{"a":"foo","b":{"c":"bar"}}"""
                    |> Expect.equal (Ok ( "foo", "bar" ))
        , test "should decode defaultAt fields" <|
            \() ->
                (defaultAt "--" string [ "a", "b" ] <|
                    \a ->
                        defaultAt "--" string [ "x", "y" ] <|
                            \b ->
                                succeed ( a, b )
                )
                    |> runWith """{"a":{},"x":{"y":"bar"}}"""
                    |> Expect.equal (Ok ( "--", "bar" ))
        , test "default succeeds if the field is not present" <|
            \() ->
                (default "--" string "a" <|
                    \a ->
                        default "--" string "x" <|
                            \b ->
                                succeed ( a, b )
                )
                    |> runWith """{"x":"five"}"""
                    |> Expect.equal (Ok ( "--", "five" ))
        , test "default succeeds with fallback if the field is present but null" <|
            \() ->
                (default "--" string "a" <|
                    \a ->
                        default "--" string "x" <|
                            \b ->
                                succeed ( a, b )
                )
                    |> runWith """{"a":null,"x":"five"}"""
                    |> Expect.equal (Ok ( "--", "five" ))
        , test "default succeeds with result of the given decoder if the field is null and the decoder decodes nulls" <|
            \() ->
                (default "--" (null "null") "a" <|
                    \a ->
                        default "--" string "x" <|
                            \b ->
                                succeed ( a, b )
                )
                    |> runWith """{"a":null,"x":"five"}"""
                    |> Expect.equal (Ok ( "null", "five" ))
        , test "default fails if the field is present but doesn't decode" <|
            \() ->
                (default "--" string "a" <|
                    \a ->
                        default "--" string "x" <|
                            \b ->
                                succeed ( a, b )
                )
                    |> runWith """{"x":5}"""
                    |> expectErr
        , test "defaultAt fails if the field is present but doesn't decode" <|
            \() ->
                (defaultAt "--" string [ "a", "b" ] <|
                    \a ->
                        defaultAt "--" string [ "x", "y" ] <|
                            \b ->
                                succeed ( a, b )
                )
                    |> runWith """{"a":{},"x":{"y":5}}"""
                    |> expectErr
        ]
