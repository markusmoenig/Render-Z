
fn init() {

    this.name = "Remove";

}

fn apply(key) {

    let tile = get_tile(key);
    tile.set(vec3i(5, 5, 5), 10);
    print(tile.size);
    set_tile(key, tile);
}

fn hit(record) {
    let tile = get_tile(record.key);
    tile.clear(record.tile_key);
    set_tile(record.key, tile);
}