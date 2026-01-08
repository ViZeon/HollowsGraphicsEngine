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



#### NEXT
- figure out a way to collect verts and choose what to render
- maybe make a search by each vert found in a certain radius of the binary search (fallback in the find relative verts section)


- get all verts from the list within 1 m
- cross reference to refine matching verts\

Or
- get closest vert from an axis (preferably depth)
- check if said vert has the closest distance to the cam's X and Y (loop through)
- if not, search X for a ....

Let's just loop through all verts


- can calc pixel range
- can calc said range based on FOV and distance
- each vert, will know its distance, and therefor can "subscribe" (or add) itself to a pixel, based on relevant range of the pixel at its distance
- instead of subbing to a specific pixel, it subs to a.. range?, and the pixel grabs it? (like 2D or 3D array of sort?)
- will need some form of treatement for culling, might be able to cull based on existing verts in similar x and y but closer z
- 




use existing binary search, add range index to limit search, utilize the get vert value function


Bin tree is very slow because of the search, switching to spatial hash



populating an array makes it hard to rach closest verts
I need an easy way to both instantly check x>y without search, then a way to find the closest z, also without search



	model_load [Testing] 117
		//TODO: Loop through X, Y and Z and assign the last occupied index for each missing bracket to a negative version of the associated index
		//Might want to reserve the first 6 keys exclusively for nearest data points 


I'm kind of an idiot
I added 6 neighbors to the CELL instead of per vert

I need to make it only per cell when they are empty (negative) and refers to the relevant vert NOT cell
I also need a sub variable (bounds) per key to deremine surrounding ones



ToDO:
- Switch from 3D dynamic array to fixed 1D array with multipliers
- Switch from model-scale based array to world-space array with 1M unit
- Switch from RayLib to SDL
- Test headless version without and display API
- Interpolation based on UV space and loops
- Change the exe name to TheHollowsEngine.exe
- Create build batch file
- Make the render system OS agnostic


Infinite Mipmapping:
- each cell has a bool for "has children", if yes, also search in
- mip levels are relative, they are /10 of the world size per level, down to 1 vertex per meter (look below)]
- above 1 meter, it's world reltive, under, it's vert count relative (PER MODEL)
- store whatever relaevant data in the cell, models add/remove themselves to the relevant cells


Need a "write to file" system for debugging large data per pixel


prepass:
- have an array/list of all potential pixels
- grab closest objects to camera, remove relevant pixels covered by said obejct (calculate the exact coverage before settling, considering normals for interpolation, inculding from pixels {mipped}, not just "what blocks are here" )
- sample remaining pixels and check closest facing obejcts, repeat
- IMPOSTANRT: this phase is DATA GATHERING only, it forwards the relevant data (everything the verts have, including their 3D positon), but does NOT draw anything on screen


hmm...
maybe I can make it grid based, and only object mips are pixel calced, but with full light influence forwarded

I will need a "screen space shadow pass" tho, where each pixel checks if there is anything between it and the light (also mipped)

or not pixel, the prepass will have a shadow pass where it goes over the geo and checks shadow casting, same idea, but only done once

so my plan for checking shadow casting in the prepass was: go over each pixel, check its 2D plane facing the light, and check its exact xy position facing that light, check that on a UV map with those coordinates on it, if it finds an occupied cell with shorter distance recorded, do nothing, if not or the distance is longer, record its own distance on these XY coordinates



the next pass, the pixel checks its distance to light and if someone else is already casting a shadow



maybe I can also store the normals of the lit/shadow casting pixel, so gradual falloff cna be calculated by the others



this is one "shadow map" per light


for global light bounces and shadows:
- each cell has normal/vector per 5 degress across all 360 degrees
- each vector has a list of contributing lights (includes bunce lighting and diffuse from other angles)
- each light source has it's starting position and falloff/diffuse
- each pixel checks the vector region aimed at it, and sets an end point to relevant lights if applicable, also contributes bounce lighting to relevant directions
- the above calc can be per vert instead of per pixel, and should interpolate the light effect across relevant vectors
- this is sampled by screen pixels later for the shadow mapping discussed earlier


detection will switch to a bit mipmap, where it stores up to 4096 meters of "Available/NA" detection in 4 kb, to make sure it's cached in the L1 cache
then we grab the relevant data from another array that has cell data

everything in the world will be classified as a "Data Point", which has a type, and a hash/ID for the relevant data block

the 4k meters are chosen beause it's a sort of "the furthest possible before a meter block is smaller than a pixel"