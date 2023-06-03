
fn init() {

    this.name = "Add";

}

fn apply(key) {
    let tile = get_tile(key);
    tile.set(vec3i(5, 5, 5), 10);
    set_tile(key, tile);
}

fn hit(record) {
    let tile = get_tile(record.key);

    // Add on the side which was hit
    let add_key = record.tile_key;
    if record.side == Side::Left {
        add_key -= vec3i(1, 0, 0);
    } else
    if record.side == Side::Right {
        add_key += vec3i(1, 0, 0);
    } else
    if record.side == Side::Top {
        add_key += vec3i(0, 1, 0);
    }
    if record.side == Side::Bottom {
        add_key -= vec3i(0, 1, 0);
    } else
    if record.side == Side::Front {
        add_key += vec3i(0, 0, 1);
    }
    if record.side == Side::Back {
        add_key -= vec3i(0, 0, 1);
    }

    tile.set(add_key, 10);
    set_tile(record.key, tile);
}