
use crate::prelude::*;

pub struct TextButton {
    rect                : Rect,

    text                : String,
    cmd                 : Option<Command>,

    clicked             : bool,
    has_state           : bool,
    state               : bool,
}

impl Widget for TextButton {

    fn new() -> Self {

        Self {
            rect        : Rect::empty(),
            text        : "".to_string(),
            cmd         : None,
            clicked     : false,
            has_state   : false,
            state       : false,
        }
    }

    fn set_rect(&mut self, rect: Rect) {
        self.rect = rect;
    }

    fn set_text(&mut self, text: String) {
        self.text = text;
    }

    fn set_cmd(&mut self, cmd: Command) {
        self.cmd = Some(cmd);
    }

    fn set_has_state(&mut self, state: bool) {
        self.state = state;
        self.has_state = true;
    }

    fn get_state(&mut self) -> bool {
        self.state
    }

    fn draw(&mut self, pixels: &mut [u8], context: &mut Context, ctx: &TheContext) {

        /*
        let color: [u8; 4] = if !self.clicked && !self.state { context.color_selected } else { context.color_button };

        let r = self.rect.to_usize();
        context.draw2d.draw_rounded_rect(pixels, &r, context.width, &color, &(6.0, 6.0, 6.0, 6.0));

        if let Some(font) = &context.font {
            context.draw2d.blend_text_rect(pixels, &r, context.width, &font, 16.0, &self.text, &context.color_text, crate::ui::draw2d::TextAlignment::Center)
        }*/
    }

    fn contains(&mut self, x: f32, y: f32) -> bool {
        if self.rect.is_inside((x as usize, y as usize)) {
            true
        } else {
            false
        }
    }

    fn touch_down(&mut self, x: f32, y: f32, context: &mut Context) -> bool {

        if self.rect.is_inside((x as usize, y as usize)) {
            context.cmd = self.cmd.clone();
            if self.has_state {
                self.state = !self.state;
            } else {
                self.clicked = true;
            }
            return true;
        }

        false
    }

    /*
    fn touch_dragged(&mut self, x: f32, y: f32, context: &mut Context) -> bool {


        true
    }*/

    fn touch_up(&mut self, _x: f32, _y: f32, _context: &mut Context) -> bool {
        if self.clicked {
            self.clicked = false;
            return true;
        }
        false
    }
}