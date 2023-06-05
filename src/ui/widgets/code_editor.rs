
use std::borrow::BorrowMut;

use crate::prelude::*;

pub struct CodeEditor {
    rect                    : Rect,

    code_drawer             : CodeDrawer

}

impl Widget for CodeEditor {

    fn new() -> Self {

        Self {
            rect            : Rect::empty(),
            code_drawer     : CodeDrawer::new(),

        }
    }

    fn set_rect(&mut self, rect: Rect) {
        self.rect = rect;
    }

    fn draw(&mut self, pixels: &mut [u8], context: &mut Context, ctx: &TheContext) {

        let mut r = self.rect.to_usize();

        ctx.draw.blend_rect(pixels, &r, ctx.width, &[0, 0, 0, 128]);

        let mut node_to_draw : Option<Node> = None;
        if let Some(curr_object) = context.curr_object {
            if let Some(object) = context.project.get_object(curr_object) {
                if let Some(curr_node) = context.curr_node {
                    if let Some(node) = object.get_node(curr_node) {
                        node_to_draw = Some(node.clone());
                    }
                }
            }
        }

        if let Some(node_to_draw) = node_to_draw {
            self.code_drawer.draw(&node_to_draw, context, ctx);
        }

        ctx.draw.blend_slice(pixels, &self.code_drawer.buffer, &(r.0, r.1, self.code_drawer.max_width, self.code_drawer.height), ctx.width);

        /*
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
        false
    }

    /*
    fn touch_dragged(&mut self, x: f32, y: f32, context: &mut Context) -> bool {


        true
    }*/

    fn touch_up(&mut self, _x: f32, _y: f32, _context: &mut Context) -> bool {
        false
    }
}