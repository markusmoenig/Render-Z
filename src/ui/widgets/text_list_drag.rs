
use crate::prelude::*;

pub struct TextListDrag {
    rect                : Rect,

    text                : Vec<String>,
    cmd                 : Option<Command>,

    clicked             : bool,
    has_state           : bool,
    state               : bool,

    text_rects          : Vec<Rect>,
}

impl Widget for TextListDrag {

    fn new() -> Self {

        Self {
            rect        : Rect::empty(),
            text        : vec![],
            cmd         : None,
            clicked     : false,
            has_state   : false,
            state       : false,
            text_rects  : vec![],
        }
    }

    fn set_rect(&mut self, rect: Rect) {
        self.rect = rect;
    }

    fn set_text_list(&mut self, text: Vec<String>) {
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

        let mut r = self.rect.to_usize();

        self.text_rects = vec![];

        r.0 += 10;
        r.1 += 10;
        r.3 = 20;

        if let Some(font) = &context.font {
            for t in &self.text {
                ctx.draw.blend_text_rect(pixels, &r, context.width, font, 16.0, &t.as_str(), &context.color_code_blue, theframework::thedraw2d::TheTextAlignment::Left);
                self.text_rects.push(Rect::new(r.0, r.1, r.2, r.3));
                r.1 += 24;
            }
        }

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
        for (index, r) in self.text_rects.iter().enumerate() {
            if r.is_inside((x as usize, y as usize)) {
                context.cmd = Some(Command::SetDragFunction(self.text[index].clone()));
                return true;
            }
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