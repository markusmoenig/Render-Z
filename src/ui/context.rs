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
    SetDragFunction(String)
}

pub struct Context {
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

    pub color_code_blue         : [u8;4],
    pub color_code_red          : [u8;4],
    pub color_code_yellow       : [u8;4],
    pub color_code_green        : [u8;4],

    pub project                 : Project,

    pub curr_object             : Option<Uuid>,
    pub curr_node               : Option<Uuid>,

    pub cmd                     : Option<Command>,

    pub curr_mode               : Mode,

    pub font                    : Option<Font>,
    pub code_font               : Option<Font>,
    pub icons                   : FxHashMap<String, (Vec<u8>, usize, usize)>,

    pub meta                    : Vec<MetaElement>,
}

impl Context {

    pub fn new() -> Self {

        // Load Font

        let mut font : Option<Font> = None;
        let mut code_font : Option<Font> = None;
        let mut icons : FxHashMap<String, (Vec<u8>, usize, usize)> = FxHashMap::default();

        for file in Embedded::iter() {
            let name = file.as_ref();
            if name.starts_with("fonts/") {
                if name.contains("Roboto") {
                    if let Some(font_bytes) = Embedded::get(name) {
                        if let Some(f) = Font::from_bytes(font_bytes.data, fontdue::FontSettings::default()).ok() {
                            font = Some(f);
                        }
                    }
                } else {
                    if let Some(font_bytes) = Embedded::get(name) {
                        if let Some(f) = Font::from_bytes(font_bytes.data, fontdue::FontSettings::default()).ok() {
                            code_font = Some(f);
                        }
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
            }
        }

        // Generate Project

        let mut project = Project::new();
        project.gen_default_shader_project();

        let curr_object = Some(project.objects[0].id);
        let curr_node = Some(project.objects[0].nodes[0].id);

        Self {
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

            color_code_blue     : [89, 154, 184, 255],
            color_code_red      : [221, 102, 154, 255],
            color_code_yellow   : [201, 187, 111, 255],
            color_code_green    : [171, 228, 214, 255],

            project,

            curr_object,
            curr_node,

            cmd                 : None,

            curr_mode           : Mode::Select,

            font,
            code_font,

            icons,

            meta                : vec![],
        }
    }

    /// Returns a reference to the current node
    pub fn get_node(&mut self) -> Option<&Node> {
        if let Some(curr_object) = self.curr_object {
            if let Some(object) = self.project.get_object(curr_object) {
                if let Some(curr_node) = self.curr_node {
                    if let Some(node) = object.get_node(curr_node) {
                        return Some(node);
                    }
                }
            }
        }
        None
    }

    /// Returns a mutable reference to the current node
    pub fn get_node_mut(&mut self) -> Option<&mut Node> {
        if let Some(curr_object) = self.curr_object {
            if let Some(object) = self.project.get_object_mut(curr_object) {
                if let Some(curr_node) = self.curr_node {
                    if let Some(node) = object.get_node_mut(curr_node) {
                        return Some(node);
                    }
                }
            }
        }
        None
    }
}