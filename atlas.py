import pathlib
from PIL import Image

texdim = 16

def atlasDim(files):
    atlas_width = 2
    atlas_height = 2

    occupied = 0
    for file in files:
        size = Image.open(file).size
        occupied += size[0] * size[1]

    while atlas_width * atlas_height < occupied:
        if atlas_width < atlas_height: atlas_width *= 2
        else: atlas_height *= 2

    return atlas_width, atlas_height

source_path = pathlib.Path("source")

normal_files = list(source_path.glob("**/*_n.png"))

atlas_width, atlas_height = atlasDim(normal_files)

print("Atlas size:", atlas_width, atlas_height)

normal_atlas = Image.new("RGBA", (atlas_width, atlas_height), color=(0, 0, 0, 0))
albedo_atlas = Image.new("RGBA", (atlas_width, atlas_height), color=(0, 0, 0, 0))

cx = 0
cy = 0
for normal_path in normal_files:
    texture_file = normal_path.stem.removesuffix("_n")
    albedo_path = normal_path.parent.joinpath(texture_file + ".png")
    print(albedo_path)
    if not albedo_path.exists():
        continue

    texture = Image.open(normal_path)

    albedo_texture = Image.open(albedo_path)

    uv_texture = Image.new("RGBA", (texture.size[0], texture.size[1]), color=(0, 0, 0, 0))
    hasalpha = albedo_texture.mode == "RGBA"

    nxT = int(texture.size[0] / texdim)
    nyT = int(texture.size[1] / texdim)
    for nx in range(0, nxT):
        for ny in range(0, nyT):
            normal_atlas.paste(texture.crop((nx * texdim, ny * texdim, (nx + 1) * texdim, (ny + 1) * texdim)), (cx, cy))
            albedo_atlas.paste(albedo_texture.crop((nx * texdim, ny * texdim, (nx + 1) * texdim, (ny + 1) * texdim)), (cx, cy))

            for x in range(0, texdim):
                for y in range(0, texdim):
                    if hasalpha == True:
                        a = albedo_texture.getpixel((nx * texdim + x, ny * texdim + y))[3]
                        if (a < 10):
                            continue
                    uv_texture.putpixel((nx * texdim + x, ny * texdim + y), (int(cx / texdim), int(cy / texdim), (int(y) << 4) | int(x), 250))

            cx += texdim
            if cx >= atlas_width:
                cx = 0
                cy += texdim

    uv_texture.save(pathlib.Path("assets/minecraft/textures/").joinpath(albedo_path.relative_to(source_path)), format="PNG")

normal_atlas.save("assets/minecraft/textures/effect/normal.png", format="PNG")
albedo_atlas.save("assets/minecraft/textures/effect/albedo.png", format="PNG")
albedo_atlas.save("assets/minecraft/textures/block/custom_atlas.png", format="PNG")