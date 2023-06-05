use crate::prelude::*;
use fontdue::Font;

#[derive(PartialEq, Clone, Debug)]
pub struct CodeDrawer {
    x                   : usize,
    y                   : usize,

    pub buffer          : Vec<u8>,

    pub meta            : Vec<MetaElement>,

    pub max_width       : usize,
    pub height          : usize,

    line_height         : f32,
    font_size           : f32,
}

impl CodeDrawer {

    pub fn new() -> Self {
        Self {
            x           : 0,
            y           : 0,

            buffer      : vec![],

            meta        : vec![],

            max_width   : 0,
            height      : 0,

            line_height : 20.0,
            font_size   : 17.0,
        }
    }

    pub fn draw(&mut self, node: &Node, context: &mut Context, ctx: & TheContext) {
        if let Some(font) = &context.code_font {
            self.gen_meta_data(node, font, ctx);

            self.buffer = vec![0; self.max_width * self.height * 4];

            for el in &self.meta {
                ctx.draw.text(&mut self.buffer, &(el.rect.x as usize, el.rect.y as usize), self.max_width, font, self.font_size, &el.text, &context.color_code_blue, &context.color_black);
            }
        }
    }

    pub fn gen_meta_data(&mut self, node: &Node, font: &Font, ctx: & TheContext) {

        self.x = 0;
        self.y = 0;
        self.buffer = vec![];
        self.meta = vec![];
        self.max_width = 0;
        self.height = self.line_height as usize;

        for n in &node.blocks {

            let text_size = ctx.draw.get_text_size(font, self.font_size, n.name.as_str());

            let el = MetaElement {
                id      : n.id,
                text    : n.name.clone() ,
                rect    : Rect::new(self.x, self.y,text_size.0, text_size.1),
            };

            self.advance(el);
        }
    }

    pub fn advance(&mut self, el: MetaElement) {
        self.x += el.rect.width + 4;
        if self.x > self.max_width {
            self.max_width = self.x;
        }
        self.meta.push(el);
    }

}

#[derive(PartialEq, Eq, Hash, Clone, Debug)]
pub struct MetaElement {
    pub id                  : Uuid,
    pub text                : String,
    pub rect                : Rect,
}