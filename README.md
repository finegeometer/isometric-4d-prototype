# 4D Isometric Rendering Prototype

## Table of Contents

- [Idea](#idea)
    - [What and Why?](#what-and-why)
    - [Understanding 4D rendering](#understanding-4d-rendering)
- [Controls](#controls)
- [Where to go from here](#where-to-go-from-here)
    - [VR](#vr)
    - [Connected Textures](#connected-textures)
    - [Game](#game)
- [Warning](#warning)

## Idea

### What and Why?

Many early 3D games were rendered with an [isometric projection](https://en.wikipedia.org/wiki/Isometric_video_game_graphics),
because it is simpler to implement and less computationally intensive than full 3D graphics.
More modern games may also use isometric projection for aesthetic or gameplay reasons.

I've thought a lot about how to render *four-dimensional* games,
and I've discovered it's really difficult.
Every approach I've tried to perspective-projecting a 4D scene
is either too computationally intensive to be feasible,
or too complicated for me to implement correctly.

But it recently occured to me that isometric projection has the same advantages in 4D as it does in 3D.
While *perspective* projection of 4D scenes is too complicated to implement, *isometric* projection is feasible.

So I implemented a prototype.

### Understanding 4D rendering

When we render a 3D world, we project it down to a 2D screen.
Similarly, when we render a *4D* world, we need to project it down to a *3D* screen.

For example, consider a 2D drawing of a 3D cube.
```text
     _*_
 _.-'   '-._
*_         _|
| '-._ _.-' |
|     *     |
|     |     |
*_    |    _*
  '-._|_.-'
      *
```

You can see three of its six square faces, somewhat squashed by the projection.
The other three faces cannot be seen, because they are obscured by the front faces.

This should be obvious. But the 4D case is analogous, and less familiar.

In a 3D drawing of a 4D hypercube, you can see four of its eight cubical faces, somewhat squashed by the projection.
The other four faces cannot be seen, because they are obscured by the front faces.

(This is the starting state of my 4D renderer; see it for a picture.)

---

There's some potential for confusion, here.
In my renderer, the camera in 4D space is fixed; you can't move it.
But you *can* change your view of the 3D picture that the 4D world is rendered to.

Here's an analogy. Draw a picture of a cube, on paper. Three faces are visible, three are not,
and you can't change which three without redrawing the picture from a different perspective. 
But of the three that are visible, you can change which is on top: just pick up and rotate the paper!

In the case of the hypercube, four faces are not shown, because they are behind the hypercube —
the bulk of hypercube is between them and the fixed 4D camera.

But in describing the 3D picture that results from the projection, you might want to say that one squashed cube is behind the others.
This is a *different* meaning of "behind", corresponding to "top of the paper" in my analogy.

Be careful not to confuse these two meanings of "behind"!

---

Here's a general tip. As you play with the 4D renderer, if you're having trouble understanding something,
try drawing the 3D equivalent on paper. It's often analogous, and much easier to understand.

## Controls

Click on the display to begin. This will "lock" the mouse pointer, until you hit escape.
All other controls only work when the pointer is locked.

The 4D camera is fixed, so it has no controls.

To change your view of the 3D screen:
- Use WASD, Space, and LeftShift to move the viewpoint.
- Move the mouse to rotate the viewpoint.

There is a cursor inside the 3D screen, used for selecting surfaces of blocks. It appears as a pure white tetrahedron.
Just as in minecraft, left clicking will destroy the block the cursor is highlighting, while right clicking will attach a new one to the highlighted face.
But since the screen is three-dimensional, the cursor is likewise capable of moving in three dimensions.

To minimize the number of controls, the cursor is always in front of the 3D viewpoint.
So by changing your view of the 3D screen, you also move the cursor.
You can scroll the mouse wheel to move the cursor towards or away from the 3D viewpoint.

If you accidentally destroy all of the blocks, refresh the page to reset.

## Where to go from here

### VR

I think this idea would work better in VR.
The view of the 3D screen would just be controlled by the user's head position, and the 3D cursor by the controller position.
(E.g. To destroy a block, put your hand in one of it's cubical faces, and click.)

Unfortunately, I do not have access to a VR headset, so even if I implemented this, I would not be able to test it.

### Connected Textures

If you have a large number of blocks in the 4D scene, the view can get fairly crowded, as every block is rendered individually.
It's the higher-dimensional equivalent of this:
```text
┌─┬─┬─┐
├─┼─┼─┘
└─┴─┘
```

This could be improved by connecting facets that are next to each other:
```text
┌─────┐
│   ┌─┘
└───┘
```

### Game

My intention with this project was to make a four-dimensional game.
Probably a puzzle game; the first few puzzles simply being about learning to interpret the 4D world.

But I'm bad at coming up with game ideas. For example,
I've implemented hyperbolic geometry simulations on eight separate occasions.
Each time, I thought I was creating a hyperbolic game.
Each time, I sucessfully implemented hyperbolic geometry,
only to have no clue how to make a game out of it.

So I'll leave it up to others to figure this out.

# Warning

Due to Elm's limited WebGL API, this prototype has a memory leak.
If left running for too long, this may cause the browser to crash.
(I believe closing the browser tab frees the memory, at least in Firefox.)

As such, I ask that you do not reuse my code.
Feel free to use the *idea* of 4D isometric rendering,
but design and implement the code yourself.
Probably in some other programming language.

(Okay, to be fair, I don't fully understand the memory leak,
so I can't be sure it's Elm's fault. But I strongly suspect it is.)
