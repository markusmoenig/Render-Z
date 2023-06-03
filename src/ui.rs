pub mod widgets;
pub mod rect;
pub mod context;

pub mod prelude {
    pub use crate::ui::widgets::*;
    pub use crate::ui::rect::Rect;
    pub use crate::ui::context::*;

    pub use crate::ui::widgets::text_button::*;
    pub use crate::ui::widgets::settings::*;
    pub use crate::ui::widgets::browser::*;
    pub use crate::ui::widgets::functionbar::*;
    pub use crate::ui::widgets::text_list_drag::*;
}

#[repr(usize)]
enum WidgetIndices {
    SettingsIndex,
    BrowserIndex,
    ModeBarIndex,
}

use WidgetIndices::*;

pub use crate::prelude::*;

pub struct UI {

    widgets                         : Vec<Box<dyn Widget>>,

    toolbar_rect                    : Rect,

    pub toolbar_height              : usize,
    pub functionbar_width           : usize,
    pub settings_width              : usize,
    pub browser_height              : usize,
}

impl UI {

    pub fn new() -> Self {

        let mut widgets : Vec<Box<dyn Widget>> = vec![];

        let settings = Box::new(Settings::new());
        widgets.push(settings);

        let browser = Box::new(Browser::new());
        widgets.push(browser);

        let modebar: Box<_> = Box::new(FunctionBar::new());
        widgets.push(modebar);

        // let perspective = Box::new(PerspectiveBar::new());
        // let property = Box::new(PropertyWidget::new());

        // widgets.push(modebar);
        // widgets.push(perspective);
        // widgets.push(property);

        Self {
            widgets,

            toolbar_rect            : Rect::empty(),

            toolbar_height          : 90,
            functionbar_width       : 100,
            settings_width          : 250,
            browser_height          : 150,
        }
    }

    pub fn draw(&mut self, pixels: &mut [u8], context: &mut Context, ctx: &TheContext) {

        // Toolbar

        self.toolbar_rect = Rect::new(0, 0, ctx.width, self.toolbar_height);
        ctx.draw.rect(pixels, &self.toolbar_rect.to_usize(), ctx.width, &context.color_toolbar);
        ctx.draw.rect(pixels, &(0, 45, ctx.width, 1), ctx.width, &[21, 21, 21, 255]);

        // Settings rect

        let settings_rect = Rect::new(context.width - self.settings_width, self.toolbar_height, self.settings_width, context.height - self.toolbar_height - self.browser_height);

        self.widgets[SettingsIndex as usize].set_rect(settings_rect.clone());

        // --- Left

        let modebar_rect: Rect = Rect::new(0, self.toolbar_height, self.functionbar_width, ctx.height - self.toolbar_height);

        self.widgets[ModeBarIndex as usize].set_rect(modebar_rect.clone());

        // --- Browser

        let browser_rect: Rect = Rect::new( self.functionbar_width, (context.height - self.browser_height), context.width - self.functionbar_width, self.browser_height);

        self.widgets[BrowserIndex as usize].set_rect(browser_rect.clone());

        // ---

        if let Some(logo) = context.icons.get(&"logo_toolbar".to_string()) {
            ctx.draw.blend_slice(pixels, &logo.0, &(2, 2, logo.1 as usize, logo.2 as usize), context.width);
        }

        for w in &mut self.widgets {
            w.draw(pixels, context, ctx);
        }
    }

    pub fn contains(&mut self, x: f32, y: f32) -> bool {
        for w in &mut self.widgets {
            if w.contains(x, y) {
                return true;
            }
        }
        false
    }

    pub fn touch_down(&mut self, x: f32, y: f32, context: &mut Context) -> bool {

        for w in &mut self.widgets {
            if w.touch_down(x, y, context) {
                return true;
            }
        }

        false
    }

    pub fn touch_dragged(&mut self, x: f32, y: f32, context: &mut Context) -> bool {

        for w in &mut self.widgets {
            if w.touch_dragged(x, y, context) {
                return true;
            }
        }

        false
    }

    pub fn touch_up(&mut self, x: f32, y: f32, context: &mut Context) -> bool {
        let mut consumed = false;

        for w in &mut self.widgets {
            if w.touch_up(x, y, context) {
                consumed = true;
            }
        }

        consumed
    }

    pub fn update(&mut self, context: &mut Context) {
        for w in &mut self.widgets {
            w.update(context);
        }
    }

}