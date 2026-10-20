// Starlink Mini roll-cage cradle mount for Can-Am (Maverick X3 / Commander / aftermarket cages)
// Parametric OpenSCAD source. Select a part with `part` and export STL.
// Units: mm.  Print rails on their outer wall face (no supports needed).
//
// Concept: two C-channel side rails capture the dish's long edges. The rails
// bolt directly onto two split tube clamps (one per rail) on a single cage
// tube that runs perpendicular to the rails. Two crossbars tie the rails
// together at the ends. A small bolt-on retainer at the front end keeps the
// dish from sliding out. The rear stops are only at the corners, so the
// dish's cable port on the short edge stays clear.

part = "assembly";  // "assembly" | "rail_rear_L" | "rail_rear_R" | "rail_front_L" | "rail_front_R"
                    // "retainer_L" | "retainer_R" | "crossbar" | "clamp_top" | "clamp_bottom"

/* ---------- Starlink Mini ---------- */
dish_L   = 298.5;   // long edge (runs along the rails)
dish_W   = 259;     // short edge (between rails)
dish_T   = 38.5;    // thickness
clr      = 1.5;     // clearance per side in length direction
gap      = dish_T + 2.5;   // channel height: room for 1-2 mm foam tape on one face

/* ---------- Cage tube ---------- */
tube_od  = 47.0;    // 1.85" = 47.0 (Maverick X3 OEM). 1.75" = 44.45. 2.00" = 50.8
tube_clr = 0.4;     // radial clearance for a rubber strip / paint

/* ---------- Rail geometry ---------- */
wall      = 4;       // outer wall thickness
flange_t  = 6;       // bottom flange thickness
flange_w  = 34;      // bottom flange width (from outer face)
lip_t     = 4;       // top lip thickness
lip_w     = 16;      // top lip width (from outer face) -> 12 mm over dish face
ch_depth  = lip_w;   // channel depth (dish edge sits in y: wall..lip_w)
stop_t    = 4;       // rear corner stop thickness
ret_zone  = 20;      // extra length at front for the retainer
rail_L    = stop_t + 2*clr + dish_L + ret_zone;   // 325.5 total
joint_x   = 162;     // half-lap joint position from rear end
lap_L     = 40;      // half-lap tongue length
rail_H    = flange_t + gap + lip_t;

hole_d    = 5.5;     // M5 clearance
hole_y    = 25;      // bolt column position across the flange
grid0     = 12;      // first grid hole from rear end
grid_p    = 20;      // grid pitch
grid_n    = 16;      // number of grid holes (12 .. 312)

/* ---------- Clamp ---------- */
clamp_wall = 8;
clamp_w    = 30;      // along tube
ear_w      = 16;
ear_t      = 8;       // per half
ear_hole   = 6.5;     // M6
pad_L      = 50;      // along rail (across tube)
pad_t      = 8;
pad_hole_sp= 20;      // = grid pitch
tilt       = 0;       // degrees, rotates pad about the tube axis

/* ---------- Crossbar ---------- */
xbar_L = 240; xbar_w = 25; xbar_t = 8; xbar_hole_sp = 220;

/* ---------- Rails: full width between rails ---------- */
rail_span = dish_W + 2*clr + 2*wall;   // outer face to outer face = 270
$fn = 64;
eps = 0.01;

module grid_holes(h = 50) {
    for (i = [0 : grid_n - 1])
        translate([grid0 + i * grid_p, hole_y, -h/2]) cylinder(d = hole_d, h = h);
}

// full-length left rail in global rail coordinates:
// x = along rail (0 = rear end), y = across (0 = outer face, +y toward dish), z = up
module rail_full() {
    difference() {
        union() {
            cube([rail_L, flange_w, flange_t]);                       // flange
            cube([rail_L, wall, rail_H]);                             // outer wall
            translate([0, 0, flange_t + gap]) cube([rail_L, lip_w, lip_t]); // top lip
            cube([stop_t, ch_depth, rail_H]);                         // rear corner stop
        }
        grid_holes();
        // chamfer the dish entry at the front lip
        translate([rail_L + eps, lip_w + eps, flange_t + gap - eps]) rotate([90,0,0])
            linear_extrude(lip_w + 2*eps) polygon([[eps,0],[-8,0],[eps,lip_t + eps]]);
    }
}

module rail_rear() {
    difference() {
        rail_full();
        // keep only rear half + tongue
        translate([joint_x, -1, flange_t/2]) cube([rail_L, flange_w + 2, rail_H]);  // remove upper flange, wall & lip beyond joint
        translate([joint_x + lap_L, -1, -1]) cube([rail_L, flange_w + 2, rail_H + 2]);  // cut tongue end
    }
}

module rail_front() {
    translate([-joint_x, 0, 0]) difference() {
        rail_full();
        translate([-1, -1, -1]) cube([joint_x + 1, flange_w + 2, rail_H + 2]);      // remove rear part
        translate([joint_x - 1, -1, -1]) cube([lap_L + 1, flange_w + 2, flange_t/2 + 1]); // lap recess
    }
}

module mirror_rail() mirror([0, 1, 0]) children();

// front retainer: block in the channel in front of the dish + foot bolted to grid hole at x=312
module retainer() {
    rx = grid0 + (grid_n - 1) * grid_p - 8;   // 304
    difference() {
        union() {
            translate([rx + 1, wall, flange_t]) cube([15, ch_depth - wall, gap - 0.5]);
            translate([rx, wall, flange_t]) cube([16, flange_w - wall, 4]);
        }
        translate([rx + 8, hole_y, 0]) cylinder(d = hole_d, h = 50);
    }
}

module crossbar() {
    difference() {
        translate([-xbar_L/2, -xbar_w/2, 0]) cube([xbar_L, xbar_w, xbar_t]);
        for (s = [-1, 1]) translate([s * xbar_hole_sp/2, 0, -1]) cylinder(d = hole_d, h = xbar_t + 2);
    }
}

// clamp: tube axis = Y, split plane z = 0. top half carries the pad.
R_in  = tube_od/2 + tube_clr;
R_out = R_in + clamp_wall;

module clamp_body() {
    rotate([90, 0, 0]) translate([0, 0, -clamp_w/2]) cylinder(r = R_out, h = clamp_w);
    for (s = [-1, 1]) translate([s * (R_out - 2 + ear_w/2) - ear_w/2, -clamp_w/2, -ear_t]) cube([ear_w, clamp_w, 2 * ear_t]);
}
module clamp_cuts() {
    rotate([90, 0, 0]) translate([0, 0, -clamp_w/2 - 1]) cylinder(r = R_in, h = clamp_w + 2);
    for (s = [-1, 1]) translate([s * (R_out - 2 + ear_w/2), 0, -50]) cylinder(d = ear_hole, h = 100);
    translate([-100, -100, -0.3]) cube([200, 200, 0.6]);   // split gap
}
module clamp_top() {
    difference() {
        union() {
            clamp_body();
            rotate([0, tilt, 0]) translate([-pad_L/2, -clamp_w/2, R_out - 3]) cube([pad_L, clamp_w, pad_t + 3]);
        }
        clamp_cuts();
        rotate([0, tilt, 0]) for (s = [-1, 1]) translate([s * pad_hole_sp/2, 0, R_out - 4]) cylinder(d = hole_d, h = 50);
        translate([-100, -100, -100]) cube([200, 200, 100]);  // keep z >= 0
    }
}
module clamp_bottom() {
    difference() {
        clamp_body();
        clamp_cuts();
        translate([-100, -100, 0]) cube([200, 200, 100]);     // keep z <= 0
    }
}

module assembly() {
    color("SteelBlue") translate([0, -rail_span/2, 0]) { rail_rear(); translate([joint_x,0,0]) rail_front(); retainer(); }
    color("SteelBlue") translate([0,  rail_span/2, 0]) mirror_rail() { rail_rear(); translate([joint_x,0,0]) rail_front(); retainer(); }
    color("Silver") for (x = [grid0, grid0 + (grid_n-1)*grid_p]) translate([x, 0, -xbar_t]) crossbar();
    color("DarkOrange") for (s = [-1, 1]) {
        cx = grid0 + 7 * grid_p + grid_p/2;   // between grid holes 8 and 9 (centered on dish)
        translate([cx, s * (rail_span/2 - hole_y), -(R_out + pad_t)]) clamp_top();
        translate([cx, s * (rail_span/2 - hole_y), -(R_out + pad_t)]) clamp_bottom();
    }
    %color("LightGray", 0.4) translate([stop_t + clr, -dish_W/2, flange_t + 1]) cube([dish_L, dish_W, dish_T]);
}

if (part == "assembly")     assembly();
if (part == "rail_rear_L")  rail_rear();
if (part == "rail_rear_R")  mirror_rail() rail_rear();
if (part == "rail_front_L") rail_front();
if (part == "rail_front_R") mirror_rail() rail_front();
if (part == "retainer_L")   retainer();
if (part == "retainer_R")   mirror_rail() retainer();
if (part == "crossbar")     crossbar();
if (part == "clamp_top")    clamp_top();
if (part == "clamp_bottom") clamp_bottom();
