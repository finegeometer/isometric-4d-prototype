port module Main exposing (..)

import Browser
import Browser.Events
import Html.Attributes
import Json.Decode
import Math.Matrix4 as Mat4 exposing (Mat4)
import Math.Vector3 as Vec3 exposing (Vec3, vec3)
import Math.Vector4 exposing (Vec4, vec4)
import Set exposing (Set)
import WebGL
import World exposing (Axis(..), World)



{- Ports -}


port onPointerLock : (Bool -> msg) -> Sub msg


port onWheel : (Float -> msg) -> Sub msg


port ready : {} -> Cmd msg



{- Main Program -}


type alias Model =
    { world : World ()
    , mesh : WebGL.Mesh Attributes
    , pos : Vec3
    , theta : Float
    , phi : Float
    , keys : Set String
    , lock : Bool
    , cursorDistance : Float
    }


type Msg
    = KeyDown String
    | KeyUp String
    | MouseMove Float Float
    | MouseWheel Float
    | Click Int
    | Frame Float
    | Visibility Browser.Events.Visibility
    | PointerLock Bool


main : Program () Model Msg
main =
    Browser.document
        { init = \() -> ( init, ready {} )
        , view = view
        , update = \msg model -> ( update msg model, Cmd.none )
        , subscriptions = subscriptions
        }


init : Model
init =
    let
        world =
            World.new |> World.update { x = 0, y = 0, z = 0, w = 0 } (\_ -> Just ())
    in
    { world = world
    , mesh = WebGL.triangles (World.mesh tetraMesh world)
    , pos = vec3 0 0 -2
    , theta = 0
    , phi = 0
    , keys = Set.empty
    , lock = False
    , cursorDistance = 1
    }


view : Model -> Browser.Document Msg
view model =
    { title = "4D Isometric Game"
    , body =
        [ WebGL.toHtml
            [ Html.Attributes.id "canvas"
            , Html.Attributes.width 800
            , Html.Attributes.height 800
            , Html.Attributes.style "background-color" "black"
            ]
            [ WebGL.entity
                vshader
                fshader
                model.mesh
                (let
                    ( cursor, axis ) =
                        World.pick model.world (untransform (cursorPos model)) |> Maybe.map (Tuple.mapBoth ivec4ToVec4 World.axisNum) |> Maybe.withDefault ( vec4 -1 -1 -1 -1, -1 )
                 in
                 { transform = Mat4.mul perspectiveMatrix (transformMatrix model)
                 , cursorCoord = cursor
                 , cursorSide = toFloat axis
                 }
                )
            , WebGL.entity
                [glsl|
                                attribute vec3 dpos;
                                uniform mat4 transform;
                                uniform vec3 pos;
                                void main() {
                                    gl_Position = transform * vec4(dpos * 0.05 + pos, 1);
                                }
                            |]
                [glsl|
                                precision mediump float;
                                void main() {
                                    gl_FragColor = vec4(1);
                                }
                            |]
                (WebGL.indexedTriangles
                    [ { dpos = vec3 1 -1 -1 }
                    , { dpos = vec3 -1 1 -1 }
                    , { dpos = vec3 -1 -1 1 }
                    , { dpos = vec3 1 1 1 }
                    ]
                    [ ( 0, 1, 2 )
                    , ( 1, 2, 3 )
                    , ( 2, 3, 0 )
                    , ( 3, 0, 1 )
                    ]
                )
                { transform = Mat4.mul perspectiveMatrix (transformMatrix model), pos = cursorPos model }
            ]
        ]
    }


update : Msg -> Model -> Model
update msg model =
    case msg of
        KeyDown k ->
            { model | keys = Set.insert k model.keys }

        KeyUp k ->
            { model | keys = Set.remove k model.keys }

        MouseMove x y ->
            { model
                | theta = x / 200 + model.theta
                , phi =
                    y
                        / 200
                        + model.phi
                        |> clamp -1.57 1.57
            }

        MouseWheel dist ->
            { model | cursorDistance = clamp 0.2 5 (model.cursorDistance - dist / 1000) }

        Click button ->
            case World.pick model.world (untransform (cursorPos model)) of
                Nothing ->
                    model

                Just ( coord, axis ) ->
                    let
                        world =
                            case button of
                                0 ->
                                    World.update coord (\_ -> Nothing) model.world

                                2 ->
                                    World.update
                                        (case axis of
                                            X ->
                                                { coord | x = coord.x + 1 }

                                            Y ->
                                                { coord | y = coord.y + 1 }

                                            Z ->
                                                { coord | z = coord.z + 1 }

                                            W ->
                                                { coord | w = coord.w + 1 }
                                        )
                                        (\_ -> Just ())
                                        model.world

                                _ ->
                                    model.world
                    in
                    { model | world = world, mesh = WebGL.triangles (World.mesh tetraMesh world) }

        Frame dt ->
            let
                { x, y, z } =
                    Vec3.toRecord model.pos

                ifPressed : String -> (a -> a) -> a -> a
                ifPressed k =
                    if Set.member k model.keys then
                        identity

                    else
                        always identity
            in
            { model
                | pos =
                    vec3
                        (x
                            |> ifPressed "KeyW" ((+) (sin model.theta * -dt / 1000))
                            |> ifPressed "KeyS" ((+) (sin model.theta * dt / 1000))
                            |> ifPressed "KeyA" ((+) (cos model.theta * dt / 1000))
                            |> ifPressed "KeyD" ((+) (cos model.theta * -dt / 1000))
                        )
                        (y
                            |> ifPressed "Space" ((+) (-dt / 1000))
                            |> ifPressed "ShiftLeft" ((+) (dt / 1000))
                        )
                        (z
                            |> ifPressed "KeyW" ((+) (cos model.theta * dt / 1000))
                            |> ifPressed "KeyS" ((+) (cos model.theta * -dt / 1000))
                            |> ifPressed "KeyA" ((+) (sin model.theta * dt / 1000))
                            |> ifPressed "KeyD" ((+) (sin model.theta * -dt / 1000))
                        )
            }

        Visibility Browser.Events.Visible ->
            model

        Visibility Browser.Events.Hidden ->
            { model | keys = Set.empty }

        PointerLock lock ->
            { model | lock = lock }


subscriptions : Model -> Sub Msg
subscriptions { keys, lock } =
    Sub.batch
        [ Sub.batch
            [ Browser.Events.onKeyDown (Json.Decode.map KeyDown (Json.Decode.field "code" Json.Decode.string))
            , Browser.Events.onKeyUp (Json.Decode.map KeyUp (Json.Decode.field "code" Json.Decode.string))
            , Browser.Events.onVisibilityChange Visibility
            , onPointerLock PointerLock
            ]
        , if lock && not (Set.isEmpty keys) then
            Browser.Events.onAnimationFrameDelta Frame

          else
            Sub.none
        , if lock then
            Sub.batch
                [ Browser.Events.onMouseMove
                    (Json.Decode.map2 MouseMove
                        (Json.Decode.field "movementX" Json.Decode.float)
                        (Json.Decode.field "movementY" Json.Decode.float)
                    )
                , onWheel MouseWheel
                , Browser.Events.onMouseDown (Json.Decode.map Click (Json.Decode.field "button" Json.Decode.int))
                ]

          else
            Sub.none
        ]


perspectiveMatrix : Mat4
perspectiveMatrix =
    Mat4.makePerspective 70 1 0.01 100


transformMatrix : Model -> Mat4
transformMatrix { pos, theta, phi } =
    Mat4.mul (Mat4.makeRotate phi (vec3 1 0 0)) <|
        Mat4.mul (Mat4.makeRotate theta (vec3 0 1 0)) <|
            Mat4.mul (Mat4.makeTranslate pos) <|
                Mat4.makeBasis (vec3 (1 / sqrt 6) (1 / 3) (1 / (3 * sqrt 2))) (vec3 (-1 / sqrt 6) (1 / 3) (1 / (3 * sqrt 2))) (vec3 0 (1 / 3) -(sqrt 2 / 3))


cursorPos : Model -> Vec3
cursorPos model =
    Mat4.transform (Mat4.inverse (transformMatrix model) |> Maybe.withDefault Mat4.identity) (vec3 0 0 -model.cursorDistance)



{- Isometric Rendering -}


type alias Attributes =
    { pos : Vec3
    , color : Vec3
    , normal : Vec3
    , coord : Vec4
    , side : Float
    }


transform : ( Int, Int, Int ) -> Vec3
transform ( x, y, z ) =
    Mat4.transform
        (Mat4.makeBasis (vec3 1 -1 -1) (vec3 -1 1 -1) (vec3 -1 -1 1))
        (vec3 (toFloat x) (toFloat y) (toFloat z))


untransform : Vec3 -> ( Float, Float, Float )
untransform v =
    let
        { x, y, z } =
            Vec3.toRecord (Mat4.transform (Mat4.makeBasis (vec3 0 -0.5 -0.5) (vec3 -0.5 0 -0.5) (vec3 -0.5 -0.5 0)) v)
    in
    ( x, y, z )


triMesh : { coord : World.IVec4, axis : Axis } -> Vec3 -> Vec3 -> Vec3 -> List ( Attributes, Attributes, Attributes )
triMesh { coord, axis } v0 v1 v2 =
    let
        color =
            case axis of
                X ->
                    vec3 1 0 0

                Y ->
                    vec3 0 1 0

                Z ->
                    vec3 0 0 1

                W ->
                    vec3 1 1 1

        normal =
            Vec3.normalize (Vec3.cross (Vec3.sub v1 v0) (Vec3.sub v2 v0))

        center =
            Vec3.scale 0.5 (Vec3.add v0 v2)

        f v =
            Vec3.add (Vec3.scale 0.8 v) (Vec3.scale 0.2 center)

        g v =
            { color = color
            , normal = normal
            , pos = v
            , coord = ivec4ToVec4 coord
            , side = toFloat <| World.axisNum axis
            }

        { p0, p1, p2, q0, q1, q2 } =
            { p0 = g v0
            , p1 = g v1
            , p2 = g v2
            , q0 = g (f v0)
            , q1 = g (f v1)
            , q2 = g (f v2)
            }
    in
    [ ( p1, p0, q0 )
    , ( p1, q0, q1 )
    , ( p1, q1, q2 )
    , ( p1, q2, p2 )
    ]


ivec4ToVec4 : World.IVec4 -> Vec4
ivec4ToVec4 { x, y, z, w } =
    vec4 (toFloat x) (toFloat y) (toFloat z) (toFloat w)


tetraMesh : { corners : List ( Int, Int, Int ), coord : World.IVec4, data : (), axis : Axis } -> List ( Attributes, Attributes, Attributes )
tetraMesh { corners, axis, coord } =
    case List.map transform corners of
        [ c0, c1, c2, c3 ] ->
            let
                center =
                    Vec3.scale 0.5 (Vec3.add c2 c3)

                f v =
                    Vec3.add (Vec3.scale 0.95 v) (Vec3.scale 0.05 center)
            in
            List.concat
                [ triMesh { coord = coord, axis = axis } (f c0) (f c1) (f c2)
                , triMesh { coord = coord, axis = axis } (f c3) (f c0) (f c1)
                ]

        _ ->
            []


type alias Uniforms =
    { transform : Mat4, cursorCoord : Vec4, cursorSide : Float }


vshader : WebGL.Shader Attributes Uniforms { vcolor : Vec3, vnorm : Vec3 }
vshader =
    [glsl|
        attribute vec3 pos;
        uniform mat4 transform;

        attribute vec3 color;
        varying vec3 vcolor;
        attribute vec3 normal;
        varying vec3 vnorm;

        attribute vec4 coord;
        uniform vec4 cursorCoord;
        attribute float side;
        uniform float cursorSide;

        void main() {
            vcolor = color;
            vnorm = normal;

            // Really, they should be exactly the same. But I'm being cautious.
            if (distance(coord, cursorCoord) < 0.1 && abs(side - cursorSide) < 0.1) {
                vcolor *= 0.5;
            } 

            gl_Position = transform * vec4(pos, 1);
        }
    |]


fshader : WebGL.Shader {} Uniforms { vcolor : Vec3, vnorm : Vec3 }
fshader =
    [glsl|
        precision mediump float;
        varying vec3 vcolor;
        varying vec3 vnorm;
        void main() {
            gl_FragColor = vec4(vcolor * (0.5 + abs(dot(vnorm, vec3(0.1, 0.2, 0.5)))), 1.);
        }
    |]
