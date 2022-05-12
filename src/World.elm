module World exposing (Axis(..), IVec4, World, axisNum, get, mesh, new, pick, update)

import Dict exposing (Dict)
import SearchArray exposing (SearchArray)


type alias IVec4 =
    { x : Int
    , y : Int
    , z : Int
    , w : Int
    }


type Axis
    = X
    | Y
    | Z
    | W


axisNum : Axis -> Int
axisNum axis =
    case axis of
        X ->
            0

        Y ->
            1

        Z ->
            2

        W ->
            3



{- Conversion to and from projection coordinates.
   Note that these are *not* isometric, so there is a non-orthonormal conversion to screen space.
-}


projectCoord : IVec4 -> ( Int, Int, Int )
projectCoord { x, y, z, w } =
    ( x - w, y - w, z - w )


unprojectCoord : ( Int, Int, Int ) -> Int -> IVec4
unprojectCoord ( x, y, z ) w =
    { x = x + w, y = y + w, z = z + w, w = w }



{- The World struct, representing a four-dimensional grid of blocks. -}


type World a
    = World (Dict ( Int, Int, Int ) (SearchArray a))


new : World a
new =
    World Dict.empty


get : IVec4 -> World a -> Maybe a
get coord (World world) =
    Dict.get (projectCoord coord) world
        |> Maybe.andThen (SearchArray.get coord.w)


update : IVec4 -> (Maybe a -> Maybe a) -> World a -> World a
update coord f (World world) =
    World <|
        Dict.update (projectCoord coord)
            (\column ->
                case column of
                    Just col ->
                        col
                            |> SearchArray.expandToInclude coord.w
                            |> SearchArray.update coord.w f

                    Nothing ->
                        f Nothing |> Maybe.map (SearchArray.singleton coord.w)
            )
            world



{- Rendering, in 4D isometric perspective. -}


projectAxis : Axis -> ( Int, Int, Int ) -> ( Int, Int, Int )
projectAxis axis ( x, y, z ) =
    case axis of
        X ->
            ( x + 1, y, z )

        Y ->
            ( x, y + 1, z )

        Z ->
            ( x, y, z + 1 )

        W ->
            ( x - 1, y - 1, z - 1 )


projectNegAxis : Axis -> ( Int, Int, Int ) -> ( Int, Int, Int )
projectNegAxis axis ( x, y, z ) =
    case axis of
        X ->
            ( x - 1, y, z )

        Y ->
            ( x, y - 1, z )

        Z ->
            ( x, y, z - 1 )

        W ->
            ( x + 1, y + 1, z + 1 )


permutations : List a -> List (List a)
permutations =
    let
        selectEach : List a -> List ( a, List a )
        selectEach list =
            case list of
                [] ->
                    []

                x :: xs ->
                    ( x, xs ) :: List.map (Tuple.mapSecond ((::) x)) (selectEach xs)
    in
    \list ->
        if List.isEmpty list then
            [ [] ]

        else
            selectEach list |> List.concatMap (\( x, xs ) -> List.map ((::) x) (permutations xs))


columnHeight : World a -> ( Int, Int, Int ) -> Maybe Int
columnHeight (World world) coord =
    Dict.get coord world |> Maybe.map (SearchArray.getRight >> Tuple.first)


mesh :
    ({ corners : List ( Int, Int, Int )
     , coord : IVec4
     , data : a
     , axis : Axis
     }
     -> List meshObject
    )
    -> World a
    -> List meshObject
mesh tetraMesh (World world) =
    Dict.toList world
        |> List.concatMap
            (\( coord, column ) ->
                permutations [ X, Y, Z, W ]
                    |> List.concatMap
                        (\axisOrder ->
                            let
                                coords =
                                    List.foldl
                                        (\axis ( c, list ) -> ( projectAxis axis c, c :: list ))
                                        ( coord, [] )
                                        axisOrder
                                        |> Tuple.second

                                ( height, data ) =
                                    SearchArray.getRight column

                                occluded =
                                    List.any
                                        (\c ->
                                            case columnHeight (World world) c of
                                                Just w ->
                                                    ( w, c ) > ( height, coord )

                                                Nothing ->
                                                    False
                                        )
                                        coords
                            in
                            if occluded then
                                []

                            else
                                case axisOrder of
                                    axis :: _ ->
                                        tetraMesh { corners = coords, coord = unprojectCoord coord height, data = data, axis = axis }

                                    _ ->
                                        []
                        )
            )


pick : World a -> ( Float, Float, Float ) -> Maybe ( IVec4, Axis )
pick world ( x, y, z ) =
    let
        xi =
            floor x

        yi =
            floor y

        zi =
            floor z

        xf =
            x - toFloat xi

        yf =
            y - toFloat yi

        zf =
            z - toFloat zi

        axisOrder =
            if xf < yf then
                if xf < zf then
                    if yf < zf then
                        [ X, Y, Z ]

                    else
                        [ X, Z, Y ]

                else
                    [ Z, X, Y ]

            else if yf < zf then
                if xf < zf then
                    [ Y, X, Z ]

                else
                    [ Y, Z, X ]

            else
                [ Z, Y, X ]

        { best, bestAxis } =
            List.foldl
                (\axis acc_ ->
                    let
                        acc =
                            { acc_ | coord = projectNegAxis axis acc_.coord }

                        w =
                            columnHeight world acc.coord

                        newBest =
                            case ( w, acc.best ) of
                                ( Nothing, _ ) ->
                                    False

                                ( _, Nothing ) ->
                                    True

                                ( Just w1, Just prevBest ) ->
                                    w1 > prevBest.w
                    in
                    if newBest then
                        { acc | best = Maybe.map (unprojectCoord acc.coord) w, bestAxis = axis }

                    else
                        acc
                )
                { coord = ( xi, yi, zi )
                , best = Nothing
                , bestAxis = W
                }
                (W :: axisOrder)
    in
    Maybe.map (\out -> ( out, bestAxis )) best
