# Irregular Map Creator

An old project I found lying around :)

Written in Lua for [LÖVE](https://love2d.org).

Graph creation and Point location for an irregular map formed of polygons (the idea came from an old board game).

The Graph is created as a doubly-linked list of edges, and linked edges and vertices (nodes).

Locates the point to a graph face, and finds the neighbouring faces via the connected edges.

Broadphase search is done on the face bounding boxes in a quadtree before querying the polygon edges.

Point-based (mouse) hit detection of nodes, edges and faces separately with tolerances (detection radii).

Basic loading/saving of the map data is handled, and panning/zooming with the mouse.