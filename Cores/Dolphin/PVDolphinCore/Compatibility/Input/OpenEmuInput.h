//Dolphins Internal Controll expression Reference

//Wiimote
//m_buttons->SetControlExpression(0, "A");
//m_buttons->SetControlExpression(1, "B");
//m_buttons->SetControlExpression(2, "`1`");
//m_buttons->SetControlExpression(3, "`2`");
//m_buttons->SetControlExpression(4, "-");
//m_buttons->SetControlExpression(5, "+");
//m_buttons->SetControlExpression(6, "Home");
//m_dpad->SetControlExpression(0, "UP");
//m_dpad->SetControlExpression(1, "DOWN");
//m_dpad->SetControlExpression(2, "LEFT");
//m_dpad->SetControlExpression(3, "RIGHT");
//m_ir->SetControlExpression(0, "Cursor Y-");
//m_ir->SetControlExpression(1, "Cursor Y+");
//m_ir->SetControlExpression(2, "Cursor X-");
//m_ir->SetControlExpression(3, "Cursor X+");
//Tilt:
//m_imu_gyroscope->SetControlExpression(0, "Tilt Backward");
//m_imu_gyroscope->SetControlExpression(1, "Tilt Forward");
//m_imu_gyroscope->SetControlExpression(2, "Tilt Left");
//m_imu_gyroscope->SetControlExpression(3, "Tilt Right");
//m_imu_gyroscope->SetControlExpression(3, "Tilt Modifier");
//Swing:
//m_imu_accelerometer->SetControlExpression(0, "Accel Up");
//m_imu_accelerometer->SetControlExpression(1, "Accel Down");
//m_imu_accelerometer->SetControlExpression(2, "Accel Left");
//m_imu_accelerometer->SetControlExpression(3, "Accel Right");
//m_imu_accelerometer->SetControlExpression(4, "Accel Forward");
//m_imu_accelerometer->SetControlExpression(5, "Accel Backward");
//Gyro:
//m_imu_gyroscope->SetControlExpression(0, "Gyro Pitch Up");
//m_imu_gyroscope->SetControlExpression(1, "Gyro Pitch Down");
//m_imu_gyroscope->SetControlExpression(2, "Gyro Roll Left");
//m_imu_gyroscope->SetControlExpression(3, "Gyro Roll Right");
//m_imu_gyroscope->SetControlExpression(4, "Gyro Yaw Left");
//m_imu_gyroscope->SetControlExpression(5, "Gyro Yaw Right");

typedef enum _OEDolDev
{
    OEDolDevNone,
    OEDolDevJoy,
    OEDolDevMouse,
    OEDolDevKeyboard,
    OEDolDevLightGun,
    OEDolDevAnalog,
    OEDolDevPointer
} OEDolDevs;

typedef enum _OEGCDigital
{
    OEGCDigitalL = 21,
    OEGCDigitalR
} OEGCDigital;

typedef enum _OEWiiConType
{
    OEWiimote = 1,
    OEWiimoteSW,
    OEWiimoteNC,
    OEWiimoteCC,
    OEWiimoteCC_Pro,
    OEWiiMoteReal
} OEWiiConType;

namespace Input
{
    typedef int16_t (*openemu_input_state_t)(unsigned port, unsigned device, unsigned index, unsigned id);
    typedef void (*openemu_input_poll_t)();
    
    void openemu_set_controller_port_device(unsigned port, unsigned device);
    void openemu_set_input_state(openemu_input_state_t);
    void openemu_set_input_poll(openemu_input_poll_t);
    
    void Openemu_Input_Init();
    void OpenEmu_Input_Update();
    void ResetControllers();
}
