
fn init() {

    this.name = "Floor";

}

fn apply(key) {

    let tile = get_tile(key);
    tile.set(vec3i(5, 5, 5), 10);
    print(tile.size);
    set_tile(key, tile);
}
