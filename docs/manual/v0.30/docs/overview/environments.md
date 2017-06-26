## Environments

As a reactive language, Céu depends on an external host platform, known as an
*environment*, which exposes `input` and `output` events programs can use.

An environment senses the world and broadcasts `input` events to programs.
It also intercepts programs signalling `output` events to actuate in the
world:

![](overview/environment.png)

As examples of typical environments, an embedded system may provide button
input and LED output, and a video game engine may provide keyboard input and
video output.

<!--
`TODO: link to compilation`
-->
