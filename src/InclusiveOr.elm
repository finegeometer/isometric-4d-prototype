module InclusiveOr exposing (..)


type InclusiveOr a b
    = Left a
    | Right b
    | Both a b


fromMaybes : ( Maybe a, Maybe b ) -> Maybe (InclusiveOr a b)
fromMaybes pair =
    case pair of
        ( Nothing, Nothing ) ->
            Nothing

        ( Just a, Nothing ) ->
            Just (Left a)

        ( Nothing, Just b ) ->
            Just (Right b)

        ( Just a, Just b ) ->
            Just (Both a b)


toMaybes : Maybe (InclusiveOr a b) -> ( Maybe a, Maybe b )
toMaybes i =
    case i of
        Nothing ->
            ( Nothing, Nothing )

        Just (Left a) ->
            ( Just a, Nothing )

        Just (Right b) ->
            ( Nothing, Just b )

        Just (Both a b) ->
            ( Just a, Just b )


preferLeft : InclusiveOr a b -> Result b a
preferLeft i =
    case i of
        Left a ->
            Ok a

        Right b ->
            Err b

        Both a _ ->
            Ok a


preferRight : InclusiveOr a b -> Result a b
preferRight i =
    case i of
        Left a ->
            Err a

        Right b ->
            Ok b

        Both _ b ->
            Ok b


left : InclusiveOr a b -> Maybe a
left =
    preferLeft >> Result.toMaybe


right : InclusiveOr a b -> Maybe b
right =
    preferRight >> Result.toMaybe


map : (a1 -> a2) -> (b1 -> b2) -> InclusiveOr a1 b1 -> InclusiveOr a2 b2
map f g i =
    case i of
        Left a ->
            Left (f a)

        Right b ->
            Right (g b)

        Both a b ->
            Both (f a) (g b)
