module Json.Decode.Extra exposing (require, default, defaultAt)

{-|


# Json.Decode.Extra

Experimental API for building JSON decoders.


## Decoding fields

@docs require, default, defaultAt

-}

import Json.Decode as Decode exposing (Decoder)


{-| Decode a required field.


    type alias User =
        { id : Int
        , followers : Int
        , email : String
        }

    userDecoder : Decoder User
    userDecoder =
        require int "id" <| \id ->
        require int "followers" <| \followers ->
        require string "email" <| \email ->
        succeed { id = id, followers = followers, email = email }

    result : Result String User
    result =
        Decode.decodeString
            userDecoder
            """
            {"id": 123, "email": "sam@example.com", "followers": 42 }
            """


    --> Ok { id = 123, followers = 42, email = "sam@example.com" }

-}
require : Decoder a -> String -> (a -> Decoder b) -> Decoder b
require valDecoder fieldName andThenCallback =
    Decode.field fieldName valDecoder
        |> Decode.andThen andThenCallback


{-| Decode a field that may be missing or have a null value. If the field is
missing, then it decodes as the `fallback` value. If the field is present,
then `valDecoder` is used to decode its value. If `valDecoder` fails on a
`null` value, then the `fallback` is used as if the field were missing
entirely.


    type alias User =
        { id : Int
        , followers : Int
        , email : String
        }

    userDecoder : Decoder User
    userDecoder =
        require int "id" <| \id ->
        default 0 int "followers" <| \followers ->
        require string "email" <| \email ->
        succeed { id = id, followers = followers, email = email }

    result : Result String User
    result =
        Decode.decodeString
            userDecoder
            """
            {"id": 123, "email": "sam@example.com" }
            """


    --> Ok { id = 123, followers = 0, email = "sam@example.com" }

Because `valDecoder` is given an opportunity to decode `null` values before
resorting to the `fallback`, you can distinguish between missing and `null`
values if you need to:

    userDecoder : Decoder User
    userDecoder =
        require int "id" <| \id ->
        default 0 (oneOf [ int, null 0 ]) "followers" <| \followers ->
        require string "email" <| \email ->
        succeed { id = id, followers = followers, email = email }

-}
default : a -> Decoder a -> String -> (a -> Decoder b) -> Decoder b
default defaultVal valDecoder fieldName andThenCallback =
    optionalDecoder (Decode.field fieldName Decode.value) valDecoder defaultVal
        |> Decode.andThen andThenCallback


{-| Decode an optional nested field.

This is the same as `default` except it uses `Json.Decode.at` in place of
`Json.Decode.field`.

-}
defaultAt : a -> Decoder a -> List String -> (a -> Decoder b) -> Decoder b
defaultAt defaultVal valDecoder path andThenCallback =
    optionalDecoder (Decode.at path Decode.value) valDecoder defaultVal
        |> Decode.andThen andThenCallback


optionalDecoder : Decoder Decode.Value -> Decoder a -> a -> Decoder a
optionalDecoder pathDecoder valDecoder fallback =
    let
        nullOr decoder =
            Decode.oneOf [ decoder, Decode.null fallback ]

        handleResult input =
            case Decode.decodeValue pathDecoder input of
                Ok rawValue ->
                    -- The field was present, so now let's try to decode that value.
                    -- (If it was present but fails to decode, this should and will fail!)
                    case Decode.decodeValue (nullOr valDecoder) rawValue of
                        Ok finalResult ->
                            Decode.succeed finalResult

                        Err finalErr ->
                            -- TODO is there some way to preserve the structure
                            -- of the original error instead of using toString here?
                            Decode.fail (Decode.errorToString finalErr)

                Err _ ->
                    -- The field was not present, so use the fallback.
                    Decode.succeed fallback
    in
    Decode.value
        |> Decode.andThen handleResult
