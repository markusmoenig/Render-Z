use crate::prelude::*;
use fontdue::Font;

#[derive(PartialEq, Clone, Debug)]
pub enum Mode {
    Select,
    Camera,
    Edit,
}

#[derive(PartialEq, Clone, Debug)]
pub enum Command {
    None
}

pub struct Context {
    //pub shapes              : Vec<Tile>,
    //pub patterns            : Vec<Box<dyn Pattern>>,

    pub width                   : usize,
    pub height                  : usize,

    pub color_button            : [u8;4],
    pub color_widget            : [u8;4],
    pub color_toolbar           : [u8;4],
    pub color_selected          : [u8;4],
    pub color_text              : [u8;4],
    pub color_orange            : [u8;4],
    pub color_green             : [u8;4],
    pub color_red               : [u8;4],
    pub color_blue              : [u8;4],
    pub color_white             : [u8;4],
    pub color_black             : [u8;4],

    pub curr_key                : Option<Vec3i>,

    pub curr_tool               : Tool,
    pub curr_tools              : Vec<String>,

    pub cmd                     : Option<Command>,

    pub curr_mode               : Mode,

    pub font                    : Option<Font>,
    pub icons                   : FxHashMap<String, (Vec<u8>, usize, usize)>,

    // Tools

    pub tools                   : FxHashMap<String, Tool>,

    /*
    pub curr_perspective    : Perspective,
    pub curr_shape          : usize,
    pub curr_pattern        : usize,
    pub curr_color_index    : usize,

    pub curr_property       : Props,
    pub curr_properties     : Properties,

    pub selected_pos        : Option<(i32, i32)>,
    pub selected_id         : Option<Uuid>,

    pub font                : Option<Font>,
    pub icons               : FxHashMap<String, (Vec<u8>, u32, u32)>,

    pub palette             : Palette,*/
}

impl Context {

    pub fn new() -> Self {

        let mut curr_tool = Tool::new("".into());
        let mut curr_tools = vec![];

        let mut tools : FxHashMap<String, Tool> = FxHashMap::default();

        // Load Font

        let mut font : Option<Font> = None;
        let mut icons : FxHashMap<String, (Vec<u8>, usize, usize)> = FxHashMap::default();

        for file in Embedded::iter() {
            let name = file.as_ref();
            if name.starts_with("fonts/") {
                if let Some(font_bytes) = Embedded::get(name) {
                    if let Some(f) = Font::from_bytes(font_bytes.data, fontdue::FontSettings::default()).ok() {
                        font = Some(f);
                    }
                }
            } else
            if name.starts_with("icons/") {
                if let Some(file) = Embedded::get(name) {
                    let data = std::io::Cursor::new(file.data);

                    let decoder = png::Decoder::new(data);
                    if let Ok(mut reader) = decoder.read_info() {
                        let mut buf = vec![0; reader.output_buffer_size()];
                        let info = reader.next_frame(&mut buf).unwrap();
                        let bytes = &buf[..info.buffer_size()];

                        let mut cut_name = name.replace("icons/", "");
                        cut_name = cut_name.replace(".png", "");
                        icons.insert(cut_name.to_string(), (bytes.to_vec(), info.width as usize, info.height as usize));
                    }
                }
            } else
            if name.starts_with("tools/") {
                if let Some(bytes) = Embedded::get(name) {
                    if let Some(string) = std::str::from_utf8(bytes.data.as_ref()).ok() {
                        //println!("{}", string);

                        let mut tool = Tool::new(string.into());

                        //tool.init(&mut engine);
                        let name = tool.name();
                        println!("{}", name);

                        curr_tool = tool.clone();

                        curr_tools.push(name.clone());
                        tools.insert(name, tool);
                    }
                }
            }
        }

        // --
        /*
        let palette = Palette::new();

        let mut shapes : Vec<Tile> = vec![];

        /*
        let mut tile = Tile::new(100);
        tile.shapes.push(Box::new(Wall::new()));
        tile.shapes[0].update();
        tile.render(&palette);

        shapes.push(tile);*/

        let mut tile = Tile::new(100);
        tile.shapes.push(Box::new(Voxels::new()));
        tile.shapes[0].update();
        tile.render(&palette);

        shapes.push(tile);

        let mut patterns : Vec<Box<dyn Pattern>> = vec![];

        let brick = Brick::new();
        patterns.push(Box::new(brick));

        let value = Value::new();
        patterns.push(Box::new(value));

        let voronoi: Voronoi = Voronoi::new();
        patterns.push(Box::new(voronoi));
        */

        Self {
            // shapes,
            // patterns,

            width               : 0,
            height              : 0,

            color_button        : [53, 53, 53, 255],
            color_selected      : [135, 135, 135, 255],
            color_widget        : [24, 24, 24, 255],
            color_toolbar       : [29, 29, 29, 255],
            color_text          : [244, 244, 244, 255],
            color_orange        : [188, 68, 34, 255],
            color_green         : [10, 93, 80, 255],
            color_red           : [207, 55, 54, 255],
            color_blue          : [27, 79, 136, 255],
            color_white         : [255, 255, 255, 255],
            color_black         : [0, 0, 0, 255],

            curr_key            : None,

            curr_tool,
            curr_tools,

            cmd                 : None,

            curr_mode           : Mode::Select,

            font,
            icons,

            tools,

            // curr_mode       : Mode::InsertShape,
            // curr_shape      : 0,
            // curr_pattern    : 0,
            // curr_color_index: 3,

            // curr_property   : Props::Shape,
            // curr_properties : Properties::new(),

            // selected_pos    : None,
            // selected_id     : None,

            // curr_perspective: Perspective::Iso,

            // font,
            // icons,

            // palette,
        }
    }
}