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
