use crate::prelude::*;

use std::f32::consts::PI;

#[derive(Serialize, Deserialize, PartialEq, Debug, Clone)]
pub struct Ray {
    pub o           : Vec3f,
    pub d           : Vec3f,
}

impl Ray {

    pub fn new(o : Vec3f, d : Vec3f) -> Self {
        Self {
            o,
            d,
        }
    }

    /// Returns the position on the ray at the given distance
    pub fn at(&self, d: f32) -> Vec3f {
        self.o + self.d * d
    }
}

#[derive(Serialize, Deserialize, PartialEq, Debug, Clone)]
pub struct Camera {
    pub origin      : Vec3f,
    pub center      : Vec3f,
    pub fov         : f32,
}

impl Camera {

    pub fn new(origin: Vec3f, center: Vec3f, fov: f32) -> Self {
        Self {
            origin,
            center,
            fov
        }
    }

    // Set the camera's origin and center based on the top-down angle (in degrees)
    pub fn set_top_down_angle(&mut self, angle_deg: f32, distance: f32, look_at: Vec3f) {
        let angle_rad = angle_deg.to_radians();
        let height = distance * angle_rad.sin();
        let horizontal_distance = distance * angle_rad.cos();

        self.center = look_at;

        // Assuming the camera looks along the negative z-axis by default
        self.origin = Vec3f {
            x: look_at.x,
            y: look_at.y + height,
            z: look_at.z - horizontal_distance,
        };
    }

    // Move the camera by a given displacement
    pub fn zoom(&mut self, delta: f32) {
        let direction = normalize(self.center - self.origin);

        self.origin += direction * delta;
        self.center += direction * delta;
    }

    // Move the camera by a given displacement
    pub fn move_by(&mut self, x_offset: f32, y_offset: f32) {
        // self.origin += Vec3f::new(x_offset, y_offset, 0.0);
        // self.center += Vec3f::new(x_offset, y_offset, 0.0);

        let direction = normalize(self.center - self.origin);
        let up_vector = vec3f(0.0, 1.0, 0.0);
        let right_vector = cross(direction, up_vector);

        let displacement = right_vector * x_offset + up_vector * y_offset;

        self.origin += displacement;
        self.center += displacement;

        /*
        let direction = normalize(self.center - self.origin);
        let up_vector = vec3f(0.0, 1.0, 0.0);
        let right_vector = cross(direction, up_vector);

        self.origin += direction * y_offset + right_vector * x_offset;
        self.center += direction * y_offset + right_vector * x_offset;*/
    }

    // Pan the camera horizontally and vertically
    pub fn pan(&mut self, horizontal: f32, vertical: f32) {
        let w = normalize(self.origin - self.center);
        let up_vector = vec3f(0.0, 1.0, 0.0);
        let u = cross(up_vector, w);
        let v = cross(w, u);

        self.center += u * horizontal + v * vertical;
    }

    // Rotate the camera around its center
    pub fn rotate(&mut self, yaw: f32, pitch: f32) {

        fn magnitude(vec: Vec3f) -> f32 {
            (vec.x.powi(2) + vec.y.powi(2) + vec.z.powi(2)).sqrt()
        }

        let radius = magnitude(self.origin - self.center);

        let mut theta = ((self.origin.z - self.center.z) / radius).acos();
        let mut phi = ((self.origin.x - self.center.x) / (radius * theta.sin())).acos();

        theta += pitch.to_radians();
        phi += yaw.to_radians();

        theta = theta.max(0.1).min(PI - 0.1);

        self.origin.x = self.center.x + radius * theta.sin() * phi.cos();
        self.origin.y = self.center.y + radius * theta.cos();
        self.origin.z = self.center.z + radius * theta.sin() * phi.sin();
    }

    /// Create a pinhole ray
    pub fn create_ray(&self, uv: Vec2f, screen: Vec2f, offset: Vec2f) -> Ray {
        let ratio = screen.x / screen.y;
        let pixel_size = vec2f(1.0 / screen.x, 1.0 / screen.y);

        let half_width = (self.fov.to_radians() * 0.5).tan();
        let half_height = half_width / ratio;

        let up_vector = vec3f(0.0, 1.0, 0.0);

        let w = normalize(self.origin - self.center);
        let u = cross(up_vector, w);
        let v = cross(w, u);

        let lower_left = self.origin - u * half_width - v * half_height - w;
        let horizontal = u * half_width * 2.0;
        let vertical = v * half_height * 2.0;
        let mut dir = lower_left - self.origin;

        dir += horizontal * (pixel_size.x * offset.x + uv.x);
        dir += vertical * (pixel_size.y * offset.y + uv.y);

        Ray::new(self.origin, normalize(dir))
    }

    pub fn create_ray_persp(&self, uv: Vec2f, screen: Vec2f, offset: Vec2f) -> Ray {
        let ratio = screen.x / screen.y;

        /*
        let up_vector = vec3f(0.0, 1.0, 0.0);
        let w = normalize(self.origin - self.center);
        let u = cross(up_vector, w);
        let v = cross(w, u);

        let ortho_width = self.fov * ratio;
        let ortho_height = self.fov;

        let pixel_size = vec2f(ortho_width / screen.x, ortho_height / screen.y);

        let lower_left = self.center - u * (ortho_width * 0.5) - v * (ortho_height * 0.5);
        let mut dir = lower_left - self.origin;

        dir += u * (pixel_size.x * offset.x + uv.x);
        dir += v * (pixel_size.y * offset.y + uv.y);*/

        let pixel_size = vec2f(1.0 / screen.x, 1.0 / screen.y);

        let half_width = (self.fov.to_radians() * 0.5).tan();
        let half_height = half_width / ratio;

        let up_vector = vec3f(0.0, 1.0, 0.0);

        let w = normalize(self.origin - self.center);
        let u = cross(up_vector, w);
        let v = cross(w, u);

        let lower_left = self.origin - u * half_width - v * half_height - w;
        let horizontal = u * half_width * 1.72;
        let vertical = v * half_height * 2.0;
        //let mut dir = lower_left - self.origin;

        //dir += horizontal * (pixel_size.x * offset.x + uv.x);
        // dir += vertical * (pixel_size.y * offset.y + uv.y);

        let mut origin = self.origin;
        origin += horizontal * (pixel_size.x * offset.x + uv.x);
        origin += vertical * (pixel_size.y * offset.y + uv.y);

        Ray::new(origin, normalize(-w))
    }
}


#[derive(Serialize, Deserialize, PartialEq, Debug, Clone)]
pub struct OrbitCamera {
    pub origin          : Vec3f,
    pub center          : Vec3f,
    pub fov             : f32,

    pub azimuth         : f32,
    pub elevation       : f32,
}

impl OrbitCamera {

    pub fn new() -> Self {
        Self {
            origin      : Vec3f::zero(),
            center      : Vec3f::zero(),
            fov         : 45.0,

            azimuth     : 0.0,
            elevation   : 0.0,
        }
    }

    pub fn update(&mut self) {

        let radius = length(self.origin - self.center);

        let new_origin = vec3f(
            radius * self.elevation.to_radians().cos() * self.azimuth.to_radians().sin(),
            radius * self.elevation.to_radians().sin(),
            radius * self.elevation.to_radians().cos() * self.azimuth.to_radians().cos()
        );

        self.origin = self.center + new_origin;
    }

    /// Create a pinhole ray
    pub fn create_ray(&self, uv: Vec2f, screen: Vec2f, offset: Vec2f) -> Ray {
        let ratio = screen.x / screen.y;
        let pixel_size = vec2f(1.0 / screen.x, 1.0 / screen.y);

        let half_width = (self.fov.to_radians() * 0.5).tan();
        let half_height = half_width / ratio;

        let up_vector = vec3f(0.0, 1.0, 0.0);

        let w = normalize(self.origin - self.center);
        let u = cross(up_vector, w);
        let v = cross(w, u);

        let lower_left = self.origin - u * half_width - v * half_height - w;
        let horizontal = u * half_width * 2.0;
        let vertical = v * half_height * 2.0;
        let mut dir = lower_left - self.origin;

        dir += horizontal * (pixel_size.x * offset.x + uv.x);
        dir += vertical * (pixel_size.y * offset.y + uv.y);

        Ray::new(self.origin, normalize(dir))
    }
}