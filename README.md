# elm-json-experiment

It's right there in the name, but just to be totally clear about it:

⚠️  **THIS IS AN EXPERIMENT!** ⚠️

I have a hypothesis that these may be good ideas, but they may not be! The
purpose of this package is to facilitate trying them out and learning more.

### Goal of the experiment

Address the same use cases as `elm-json-decode-pipeline` in a way that's easier
to customize and less error-prone.

### Background

`elm-json-decode-pipeline` was created to address two use cases:

1. Decoding arbitrarily long JSON objects.
2. Decoding JSON objects where some fields might be missing.

It's designed to do this by making use of the record constructor function created
by declaring a `type alias` of a record. Here's a typical usage:

```elm
type alias User =
    { id : Int
    , email : String
    , name : String
    }


decoder : Decoder User
decoder =
    succeed User
        |> required "id" int
        |> required "email" string
        |> optional "name" string "Guest"
```

This will continue to work if we add fields to `User`, which is nice.

However, there are a few issues with this approach.

1. If I swap the order of `email` and `name` in my `type alias`, the decoder will still compile, but it will no longer behave correctly. This is an easy mistake to make because rearranging a `type alias` is typically harmless; record field order doesn't matter except when using the constructor function.
2. The types involved are extremely unusual. The first line, `succeed User` has the type `Decoder (Int -> String -> String -> User)`. The type of `required` is `String -> Decoder a -> Decoder (a -> b) -> Decoder b`, and the `Decoder (a -> b)` argument gets passed in by `|>`. These strange types combine for a notoriously difficult learning experience, as well as degraded compiler error messages.
3. Customization is often challenging. It's straightforward to add a `|> Decode.map` to the end of the pipeline, but if some fields need to be decoded differently depending on what has happened in earlier steps (e.g. the JSON object has a `"type":` field which determines the shape of the rest of the object) it's often not obvious how to do this with the `Decode.Pipeline` APIs.

### The Experimental API

Here is the original example using the proposed API.

> Note: This is not how `elm-format` would format this code. The experiment
> presumes that if this proves to be a sufficiently beneficial approach,
> `elm-format` could introduce support for this style.

```elm
type alias User =
    { id : Int
    , email : String
    , name : String
    }


decoder : Decoder User
decoder =
    require "id" int <| \id ->
    require "email" string <| \email ->
    default "name" string "Guest" <| \name ->
    succeed { id = id, email = email, name = name }
```

Much like how `else if` is an `else` followed by a nested `if` (except formatted without indentation), this is a sequence of nested anonymous functions (except formatted without indentation).

> An indented version might look like this:
>
> ```elm
> decoder : Decoder User
> decoder =
>     require "id" int <|
>         \id ->
>             require "email" string <|
>                 \email ->
>                     default "name" string "Guest" <|
>                         \name ->
>                             succeed { id = id, email = email, name = name }
> ```

This addresses all 3 of the previous concerns with `elm-json-decode-pipeline`:

1. If I swap the order of `email` and `name` in my `type alias`, everything will continue to work correctly. This version is not at all coupled to the order in `type alias` because it does not use the type alias record constructor function.
2. The types involved are variations on common ones. `require : String -> Decoder a -> (a -> Decoder b) -> Decoder b` is a flipped `andThen : (a -> Decoder b) -> Decoder a -> Decoder b` with an added `String` for the field name. Most of the package's implementation can be explained in a sentence: "`require` is a convenience function that calls `field` followed by `andThen`". Most of the rest can be explained as "`default` provides a default value to use if a field is missing."
3. Customization is trivial. I can introduce a `let` in between any of these steps, and its results will be in scope for the final call to `succeed`.

To illustrate the last point, here's a comparison of decoding into a custom type:

```elm
type User =
    User
        { id : Int
        , email : String
        , name : String
        , selected : Bool
        }


decoder : Decoder User
decoder =
    require "id" int <| \id ->
    require "email" string <| \email ->
    default "name" string "Guest" <| \name ->
    succeed (User { id = id, email = email, name = name, selected = False })
```

```elm
type User =
    User UserRecord


type alias UserRecord
    { id : Int
    , email : String
    , name : String
    , selected : Bool
    }


decoder : Decoder User
decoder =
    succeed UserRecord
        |> required "id" int
        |> required "email" string
        |> optional "name" string "Guest"
        |> hardcoded False
        |> Decode.map User
```

The difference is also significant when additional processing is involved. Suppose
we store `name` internally but it is stored in JSON as `first_name` and `last_name`.

```elm
type User =
    User
        { id : Int
        , email : String
        , name : String
        }


decoder : Decoder User
decoder =
    require "id" int <| \id ->
    require "email" string <| \email ->
    require "first_name" string <| \firstName ->
    require "last_name" string <| \lastName ->
    let
        name =
            firstName ++ " " ++ lastName
    in
    succeed { id = id, email = email, name = name }
```

A `let` can be introduced in between any of these steps just as easily, which
in turn makes it easy to decode later fields differently based on earlier fields.
(This might come up if one of the fields is `"type":`, and its value determines
the shape of the rest of the JSON object.)

Customizations like this are less straightforward using a pipeline:

```elm
type alias User =
    { id : Int
    , email : String
    , name : String
    }


decoder : Decoder User
decoder =
    succeed finish
        |> required "id" int
        |> required "email" string
        |> custom nameDecoder


nameDecoder : Decoder String
nameDecoder =
    succeed (\firstName lastName -> firstName ++ " " ++ lastName)
        |> required "first_name" string
        |> required "last_name" string
```

In summary, this API is:

1. Less error-prone, because it does not depend on the order of fields in the `type alias`
2. Easier to learn and to understand, because the basic type involved is a flipped `andThen` with an extra `String`
3. Easier to customize, because you can introduce a `let` in between any step and use it at the end.

The only significant downside seems to be that it does not currently work well with `elm-format`.

Thanks to Mario Rogic for helping to identify this approach!
