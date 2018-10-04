To show how this package works, we'll go through these steps:

1. `field`
2. `map`
3. `andThen`
4. `require`
5. `<|`

## 1. `field`

`Decode.field` decodes a particular field from a JSON object:

```elm
usernameDecoder : Decoder String
usernameDecoder =
    Decode.field "username" Decode.string
```

This decoder will decode the string `"rtfeldman"` from the following JSON:

```js
{"id": 5, "username": "rtfeldman", "name": "Richard Feldman"}
```

However, this decoder would fail if any of the following were true:

* It was not run on a JSON **object**
* The object did not have a field called **`username`**
* The `username` field was not a **string**

## 2. `map`

`List.map` uses a function to transform each value inside a list:

```elm
List.map String.toLower [ "A", "B", "C" ]
--> [ "a", "b", "c" ]
```

`Decode.map` uses a function to transform a successfully decoded value:

```elm
Decode.map String.toLower Decode.string
```

This code returns a `Decoder String` which decodes a string, and then lowercases
it. If decoding failed (for example because it tried to run this decoder on a
number insetad of a string), then `String.toLower` will not get called.

## 3. `andThen`

`andThen` works like `map` except the transformation function has the power to
change successes into failures.

`andThen` lets us perform validation in a `Decoder`. For example, here we'll
take a string and then:

1. Check if it's empty. If it's an empty string, fail decoding.
2. If it's not empty, lowercase it.

```elm
validateAndTransform : String -> Decoder String
validateAndTransform str =
    if String.isEmpty str then
        Decode.fail "the string was empty"
    else
        Decode.succeed (String.toLower str)


decoder : Decoder String
decoder =
    Decode.andThen validateAndTransform Decode.string
```

## 4. `require`

`require` is a convenience function which does a `Decode.field`
followed by a `Decode.andThen`.

```elm
lowercaseUsernameDecoder : Decoder String
lowercaseUsernameDecoder =
    require "username" Decode.string (\str ->
        if String.isEmpty str then
            Decode.fail "the string was empty"
        else
            Decode.succeed (String.toLower str)
    )
```

We can run this decoder on the following JSON:

```js
{"id": 5, "username": "RTFELDMAN", "name": "Richard Feldman"}
```

It will give back `"rtfeldman"` because it lowercases the successfully decoded
`"RTFELDMAN"`.

This decoder would fail if any of the following were true:

* It was not run on a JSON **object**
* The object did not have a field called **`username`**
* The `username` field was not a **string**
* The `username` field was present, and a string, but the string was **empty**

## 5. `<|`

We can chain several `require` calls together to decode into a record.

```elm
type alias User =
    { id : Int, username : String, name : String }


userDecoder : Decoder User
userDecoder =
    require "username" string (\username ->
        require "id" int (\id ->
            require "name" string (\name ->
                succeed { id = id, username = username, name = name }
            )
        )
    )
```

If any of these `require` calls fails to decode, the whole decoder will fail,
because `require` uses `andThen` under the hood - meaning its transformation
function can return a failure outcome.

If they all succeed, the innermost transformation function will be run. It
already has `id`, `name,` and `username` in scope, so it can use them to
`Decode.succeed` with a `User` record.

We can make this read more like a schema if we use `<|`. The `<|` operator can
take the place of parentheses. Here's an example:

```elm
String.toLower (getStr something)
String.toLower <| getStr something
```

`<|` expects a function on the left, and calls that function passing the value
on the right. We can use this to write the above decoder without so many parentheses:

```elm
userDecoder : Decoder User
userDecoder =
    require "username" string <| \username ->
    require "id" int <| \id ->
    require "name" string <| \name ->
    succeed { id = id, username = username, name = name }
```

This way, the sequence of `require` calls can be read like a schema for the JSON.
