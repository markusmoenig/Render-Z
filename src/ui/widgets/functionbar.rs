
use crate::prelude::*;

pub struct ModeBar {

    rect                : Rect
}

impl Widget for ModeBar {

    fn new() -> Self {

        Self {
            rect        : Rect::empty()
        }
    }

    fn set_rect(&mut self, rect: Rect) {
        self.rect = rect;
    }

    fn draw(&mut self, pixels: &mut [u8], context: &mut Context, ctx: &TheContext) {

        let r: (usize, usize, usize, usize) = self.rect.to_usize();

        ctx.draw.rect(pixels, &r, ctx.width, &context.color_toolbar);
        ctx.draw.rect(pixels, &(r.0, r.1, r.2, 2), ctx.width, &[0, 0, 0, 255]);

        /*
        let mut y = r.1 + 2;
        if context.curr_mode == Mode::Select {
            ctx.draw.rect(pixels, &(r.0, y, 40, 40), ctx.width, &context.color_orange);
        }
        let move_icon: &(Vec<u8>, u32, u32) = context.icons.get(&"hand-pointing".to_string()).unwrap();
        ctx.draw.blend_slice(pixels, &move_icon.0, &(r.0 + 8, y + 9, 24, 24), context.width);

        y += 40;
        if context.curr_mode == Mode::Edit {
            ctx.draw.rect(pixels, &(r.0, y, 40, 40), ctx.width, &context.color_orange);
        }
        let insert_icon = context.icons.get(&"insert".to_string()).unwrap();
        ctx.draw.blend_slice(pixels, &insert_icon.0, &(r.0 + 8, y + 9, 24, 24), context.width);
        */
        /*
        context.draw2d.draw_rounded_rect(pixels, &r, context.width, &context.color_widget, &(10.0, 10.0, 10.0, 10.0));

        if context.curr_mode == Mode::Select {
            r.3 = 40;
            context.draw2d.draw_rounded_rect(pixels, &r, context.width, &context.color_selected, &(0.0, 10.0, 0.0, 10.0));
        } else
        if context.curr_mode == Mode::InsertShape {
            r.1 += 40;
            r.3 = 40;
            context.draw2d.draw_rounded_rect(pixels, &r, context.width, &context.color_selected, &(0.0, 0.0, 0.0, 0.0));
        }

        let r: (usize, usize, usize, usize) = self.rect.to_usize();

        let move_icon = context.icons.get(&"hand-pointing".to_string()).unwrap();
        context.draw2d.blend_slice(pixels, &move_icon.0, &(r.0 + 13, r.1 + 9, 24, 24), context.width);
        let insert_icon = context.icons.get(&"insert".to_string()).unwrap();
        context.draw2d.blend_slice(pixels, &insert_icon.0, &(r.0 + 13, r.1 + 49, 24, 24), context.width);
        */
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

            if (y as usize) < self.rect.y + 42 {
                context.curr_mode = Mode::Select;
                return true;
            } else
            if (y as usize) < self.rect.y + 42 * 2 {
                context.curr_mode = Mode::Edit;
                return true;
            }
        }

        false
    }

    /*
    fn touch_dragged(&mut self, x: f32, y: f32, context: &mut Context) -> bool {


        true
    }

    fn touch_up(&mut self, _x: f32, _y: f32, context: &mut Context) -> bool {
        false
    }*/
}