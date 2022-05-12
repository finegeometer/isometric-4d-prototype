module SearchArray exposing (SearchArray, expandToInclude, get, getLeft, getRight, singleton, update)

import Bitwise exposing (..)
import InclusiveOr exposing (InclusiveOr)


type SearchArray a
    = Z a
    | S (SearchArray (InclusiveOr a a))


expandToInclude_ : Int -> SearchArray a -> SearchArray a
expandToInclude_ =
    expandToInclude


expandToInclude : Int -> SearchArray a -> SearchArray a
expandToInclude n arr =
    case arr of
        Z a ->
            if n > 0 then
                S (expandToInclude_ (shiftRightBy 1 n) (Z (InclusiveOr.Left a)))

            else
                Z a

        S a ->
            S (expandToInclude_ (shiftRightBy 1 n) a)


singleton_ : Int -> a -> SearchArray a
singleton_ =
    singleton


singleton : Int -> a -> SearchArray a
singleton n a =
    if n == 0 then
        Z a

    else
        S
            (singleton_ (shiftRightBy 1 n)
                (if and n 1 == 0 then
                    InclusiveOr.Left a

                 else
                    InclusiveOr.Right a
                )
            )


get_ : Int -> SearchArray a -> Maybe a
get_ =
    get


get : Int -> SearchArray a -> Maybe a
get n arr =
    case arr of
        Z a ->
            if n == 0 then
                Just a

            else
                Nothing

        S arr2 ->
            get_ (shiftRightBy 1 n) arr2
                |> Maybe.andThen
                    (if and n 1 == 0 then
                        InclusiveOr.left

                     else
                        InclusiveOr.right
                    )


getLeft_ : SearchArray a -> ( Int, a )
getLeft_ =
    getLeft


getLeft : SearchArray a -> ( Int, a )
getLeft arr =
    case arr of
        Z a ->
            ( 0, a )

        S arr2 ->
            let
                ( i, pair ) =
                    getLeft_ arr2
            in
            case InclusiveOr.preferLeft pair of
                Ok a ->
                    ( shiftLeftBy 1 i, a )

                Err a ->
                    ( or (shiftLeftBy 1 i) 1, a )


getRight_ : SearchArray a -> ( Int, a )
getRight_ =
    getRight


getRight : SearchArray a -> ( Int, a )
getRight arr =
    case arr of
        Z a ->
            ( 0, a )

        S arr2 ->
            let
                ( i, pair ) =
                    getRight_ arr2
            in
            case InclusiveOr.preferRight pair of
                Ok a ->
                    ( or (shiftLeftBy 1 i) 1, a )

                Err a ->
                    ( shiftLeftBy 1 i, a )


update_ : Int -> (Maybe a -> Maybe a) -> SearchArray a -> Maybe (SearchArray a)
update_ =
    update


{-| A SearchArray cannot be empty. So this returns Nothing if you delete the last remaining item in the array.
-}
update : Int -> (Maybe a -> Maybe a) -> SearchArray a -> Maybe (SearchArray a)
update i f arr =
    case arr of
        Z a ->
            if i == 0 then
                Maybe.map Z (f (Just a))

            else
                Just (Z a)

        S arr2 ->
            Maybe.map S
                (update_ (shiftRightBy 1 i)
                    (InclusiveOr.toMaybes
                        >> (if and i 1 == 0 then
                                Tuple.mapBoth f identity

                            else
                                Tuple.mapBoth identity f
                           )
                        >> InclusiveOr.fromMaybes
                    )
                    arr2
                )
