// CODE BELOW NEEDS REPLACEMENT!!
 

#### spatial sorting verts in world space [delayed for later]
- ~~3 arrays (x, y and z) to sort by each axis~~
- ~~each array element, also contains the index of the releveant vert in the original list~~

#### find the verts relative to the pixel
- Binary search to find closest
[might not need]
- Search backwards and forward to determin the range based on the passed pixel world range
- return the full list of verts in bound, as well as an ivec4 with the closest verts

- Bonus: grab EVERYTHING color directly from UVs NOT 3D space (IF any 3D is shaded by verts anyways)

#### What's needed for rendering
- Verts in-bound
- interpolation based on distance from verts
- Solid View based on Dot Product



