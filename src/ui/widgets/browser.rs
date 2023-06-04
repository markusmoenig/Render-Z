
use crate::prelude::*;

pub struct Browser {
    rect                : Rect,

    header_height       : usize,
    item_size           : (usize, usize),
    content_rects       : Vec<Rect>,
    ids                 : Vec<Uuid>,
}

impl Widget for Browser {

    fn new() -> Self {

        Self {
            rect            : Rect::empty(),

            header_height   : 30,
            item_size       : (120, 25),
            content_rects   : vec![],
            ids             : vec![],
        }
    }

    fn set_rect(&mut self, rect: Rect) {
        self.rect = rect;
    }

    fn draw(&mut self, pixels: &mut [u8], context: &mut Context, ctx: &TheContext) {

        let mut r = self.rect.to_usize();
        ctx.draw.rect(pixels, &r, context.width, &context.color_widget);
        ctx.draw.rect(pixels, &(r.0, r.1, 1, r.3), ctx.width, &context.color_black);
        // ctx.draw.rect(pixels, &(r.0 + r.2, r.1, 1, r.3), ctx.width, &context.color_black);
        return;
        /*
        r.3 = self.header_height;

        ctx.draw.rect(pixels, &r, ctx.width, &context.color_toolbar);
        ctx.draw.rect(pixels, &(r.0, r.1 + r.3, r.2, 1), ctx.width, &context.color_black);

        self.content_rects = vec![];
        self.ids = vec![];

        r.1 += r.3;
        r.2 = self.item_size.0;
        r.3 = self.item_size.1;

        let curr_name = context.curr_tool.name();

        self.content_rects = vec![];
        for tool_name in &context.curr_tools {

            let color = &context.color_green;
            let mut border_color = &context.color_green;
            let ro = 0.0;

            if curr_name == *tool_name {
                border_color = &context.color_white;
            }

            ctx.draw.rounded_rect_with_border(pixels, &r, ctx.width, &color, &(ro,ro, ro, ro), border_color, 1.5);

            ctx.draw.text_rect(pixels, &r, ctx.width, &context.font.as_ref().unwrap(), 17.0, tool_name, &context.color_text, &color, theframework::thedraw2d::TheTextAlignment::Center);

            self.content_rects.push(Rect::from(r));

            if r.1 + r.3 > ctx.height {
                r.0 += r.2;
                r.1 = self.rect.y + self.header_height;
            } else {
                r.1 += r.3;
            }
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

        if self.contains(x, y) {

            /*
            for (index, r) in self.content_rects.iter().enumerate() {
                if r.is_inside((x as usize, y as usize)) {
                    if let Some(tool) = context.tools.get(&context.curr_tools[index]) {
                        context.curr_tool = tool.clone();
                        return true;
                    }
                }
            }*/

            /*
            if context.is_color_property(){
                for (index, r) in self.content_rects.iter().enumerate() {
                    if r.is_inside((x as u32, y as u32)) {
                        context.curr_pattern = index;
                        context.cmd = Some(Command::InsertPattern);
                    }
                }
            } else
            if context.curr_property == Props::Shape {
                for (index, r) in self.content_rects.iter().enumerate() {
                    if r.is_inside((x as u32, y as u32)) {
                        context.curr_shape = index;

                        context.selected_id = Some(self.ids[index]);
                        context.cmd = Some(Command::CopySelectedShapeProperties);
                    }
                }
            }*/

            false
        } else {
            false
        }
    }
    /*
    fn touch_dragged(&mut self, x: f32, y: f32, context: &mut Context) -> bool {


        true
    }

    fn touch_up(&mut self, _x: f32, _y: f32, context: &mut Context) -> bool {
        false
    }*/
}