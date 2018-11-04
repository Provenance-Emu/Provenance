//
//  EmulatorView.m
//  emulator
//
//  Created by admin on 1/18/15.
//  Copyright (c) 2015 reicast. All rights reserved.
//

#import "EmulatorView.h"
#import "PadViewController.h"

#include "types.h"

extern u16 kcode[4];
extern u32 vks[4];
extern s8 joyx[4],joyy[4];
extern u8 rt[4],lt[4];

@implementation EmulatorView

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

NSInteger a_button = 1;
NSInteger b_button = 2;
NSInteger x_button = 3;
NSInteger y_button = 4;
NSInteger up_pad = 5;
NSInteger down_pad = 6;
NSInteger left_pad = 7;
NSInteger right_pad = 8;
NSInteger left_trigger = 9;
NSInteger right_trigger = 10;
NSInteger start_button = 11;

- (void)setControlInput:(PadViewController *)input
{
	self.controllerView = input;
}

- (void)handleKeyDown:(UIButton*)button 
{
	PadViewController * controller = (PadViewController *)self.controllerView;
	if (button == controller.img_dpad_l || button.tag == left_pad) {
		kcode[0] &= ~(DC_DPAD_LEFT);
	}
	if (button == controller.img_dpad_r || button.tag == right_pad) {
		kcode[0] &= ~(DC_DPAD_RIGHT);
	}
	if (button == controller.img_dpad_u || button.tag == up_pad) {
		kcode[0] &= ~(DC_DPAD_UP);
	}
	if (button == controller.img_dpad_d || button.tag == down_pad) {
		kcode[0] &= ~(DC_DPAD_DOWN);
	}
	if (button == controller.img_abxy_a || button.tag == a_button) {
		kcode[0] &= ~(DC_BTN_A);
	}
	if (button == controller.img_abxy_b || button.tag == b_button) {
		kcode[0] &= ~(DC_BTN_B);
	}
	if (button == controller.img_abxy_x || button.tag == x_button) {
		kcode[0] &= ~(DC_BTN_X);
	}
	if (button == controller.img_abxy_y || button.tag == y_button) {
		kcode[0] &= ~(DC_BTN_Y);
	}
	if (button == controller.img_lt || button.tag == left_trigger) {
		lt[0] = (255);
	}
	if (button == controller.img_rt || button.tag == right_trigger) {
		rt[0] = (255);
	}
	if (button == controller.img_start || button.tag == start_button) {
		kcode[0] &= ~(DC_BTN_START);
	}
}

- (void) handleKeyUp:(UIButton*)button
{
	PadViewController * controller = (PadViewController *)self.controllerView;
	if (button == controller.img_dpad_l || button.tag == left_pad) {
		kcode[0] |= (DC_DPAD_LEFT);
	}
	if (button == controller.img_dpad_r || button.tag == right_pad) {
		kcode[0] |= (DC_DPAD_RIGHT);
	}
	if (button == controller.img_dpad_u || button.tag == up_pad) {
		kcode[0] |= (DC_DPAD_UP);
	}
	if (button == controller.img_dpad_d || button.tag == down_pad) {
		kcode[0] |= (DC_DPAD_DOWN);
	}
	if (button == controller.img_abxy_a || button.tag == a_button) {
		kcode[0] |= (DC_BTN_A);
	}
	if (button == controller.img_abxy_b || button.tag == b_button) {
		kcode[0] |= (DC_BTN_B);
	}
	if (button == controller.img_abxy_x || button.tag == x_button) {
		kcode[0] |= (DC_BTN_X);
	}
	if (button == controller.img_abxy_y || button.tag == y_button) {
		kcode[0] |= (DC_BTN_Y);
	}
	if (button == controller.img_lt || button.tag == left_trigger) {
		lt[0] = (0);
	}
	if (button == controller.img_rt || button.tag == right_trigger) {
		rt[0] = (0);
	}
	if (button == controller.img_start || button.tag == start_button) {
		kcode[0] |= (DC_BTN_START);
	}
}

@end
