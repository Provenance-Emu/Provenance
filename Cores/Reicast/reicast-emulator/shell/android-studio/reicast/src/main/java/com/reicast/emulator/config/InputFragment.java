package com.reicast.emulator.config;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.app.Dialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.os.Vibrator;
import android.preference.PreferenceManager;
import android.support.v4.app.ActivityCompat;
import android.support.v4.app.Fragment;
import android.util.Log;
import android.view.InputDevice;
import android.view.KeyEvent;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.CompoundButton;
import android.widget.CompoundButton.OnCheckedChangeListener;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.SeekBar;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import com.reicast.emulator.Emulator;
import com.reicast.emulator.R;
import com.reicast.emulator.periph.Gamepad;

import java.io.File;

public class InputFragment extends Fragment {
	private static final int PERMISSION_REQUEST = 1001;

    private OnClickListener mCallback;

	private int listenForButton = 0;
	private AlertDialog alertDialogSelectController;
	private SharedPreferences mPrefs;
	private CompoundButton switchTouchVibrationEnabled;

	Vibrator vib;

	// Container Activity must implement this interface
	public interface OnClickListener {
		void onEditorSelected(Uri uri);
	}

    @Override @SuppressWarnings("deprecation")
    public void onAttach(Activity activity) {
        super.onAttach(activity);

        // This makes sure that the container activity has implemented
        // the callback interface. If not, it throws an exception
        try {
            mCallback = (OnClickListener) activity;
        } catch (ClassCastException e) {
            throw new ClassCastException(activity.toString()
                    + " must implement OnClickListener");
        }
    }

    @Override
    public void onAttach(Context context) {
        super.onAttach(context);

        // This makes sure that the container activity has implemented
        // the callback interface. If not, it throws an exception
        try {
            mCallback = (OnClickListener) context;
        } catch (ClassCastException e) {
            throw new ClassCastException(context.getClass().toString()
                    + " must implement OnClickListener");
        }
    }

	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container,
							 Bundle savedInstanceState) {
		// Inflate the layout for this fragment
		return inflater.inflate(R.layout.input_fragment, container, false);
	}

	@Override
	public void onViewCreated(View view, Bundle savedInstanceState) {
		mPrefs = PreferenceManager.getDefaultSharedPreferences(getActivity());

		Config.vibrationDuration = mPrefs.getInt(Config.pref_vibrationDuration, 20);
		vib = (Vibrator) getActivity().getSystemService(Context.VIBRATOR_SERVICE);

		try {
			ImageView icon_a = (ImageView) getView().findViewById(
					R.id.controller_icon_a);
			icon_a.setAlpha(0.8f);
			ImageView icon_b = (ImageView) getView().findViewById(
					R.id.controller_icon_b);
			icon_b.setAlpha(0.8f);
			ImageView icon_c = (ImageView) getView().findViewById(
					R.id.controller_icon_c);
			icon_c.setAlpha(0.8f);
			ImageView icon_d = (ImageView) getView().findViewById(
					R.id.controller_icon_d);
			icon_d.setAlpha(0.8f);
		} catch (NullPointerException ex) {
			// Couldn't find images, so leave them opaque
		}

		Button buttonLaunchEditor = (Button) getView().findViewById(R.id.buttonLaunchEditor);
		buttonLaunchEditor.setOnClickListener(new View.OnClickListener() {
			public void onClick(View v) {
                mCallback.onEditorSelected(Uri.EMPTY);
			}
		});

		buttonLaunchEditor.setEnabled(isBIOSAvailable());

		final TextView duration = (TextView) getView().findViewById(R.id.vibDuration_current);
		final LinearLayout vibLay = (LinearLayout) getView().findViewById(R.id.vibDuration_layout);
		final SeekBar vibSeek = (SeekBar) getView().findViewById(R.id.vib_seekBar);

		if (mPrefs.getBoolean(Config.pref_touchvibe, true)) {
			vibLay.setVisibility(View.VISIBLE);
		} else {
			vibLay.setVisibility(View.GONE);
		}

		duration.setText(String.valueOf(Config.vibrationDuration +  " ms"));
		vibSeek.setProgress(Config.vibrationDuration);

		vibSeek.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
			public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
				duration.setText(String.valueOf(progress + 5 + " ms"));
			}

			public void onStartTrackingTouch(SeekBar seekBar) {

			}

			public void onStopTrackingTouch(SeekBar seekBar) {
				int progress = seekBar.getProgress() + 5;
				mPrefs.edit().putInt(Config.pref_vibrationDuration, progress).apply();
				Config.vibrationDuration = progress;
				vib.vibrate(progress);
			}
		});

		OnCheckedChangeListener touch_vibration = new OnCheckedChangeListener() {
			public void onCheckedChanged(CompoundButton buttonView,
										 boolean isChecked) {
				mPrefs.edit().putBoolean(Config.pref_touchvibe, isChecked).apply();
				vibLay.setVisibility( isChecked ? View.VISIBLE : View.GONE );
			}
		};
		switchTouchVibrationEnabled = (CompoundButton) getView().findViewById(
				R.id.switchTouchVibrationEnabled);
		boolean vibrate = mPrefs.getBoolean(Config.pref_touchvibe, true);
		if (vibrate) {
			switchTouchVibrationEnabled.setChecked(true);
		} else {
			switchTouchVibrationEnabled.setChecked(false);
		}
		switchTouchVibrationEnabled.setOnCheckedChangeListener(touch_vibration);

		CompoundButton micPluggedIntoController = (CompoundButton) getView().findViewById(R.id.micEnabled);
		boolean micPluggedIn = mPrefs.getBoolean(Gamepad.pref_mic, false);
		micPluggedIntoController.setChecked(micPluggedIn);
		if (getActivity().getPackageManager().hasSystemFeature(PackageManager.FEATURE_MICROPHONE)) {
			// Microphone is present on the device
			micPluggedIntoController
					.setOnCheckedChangeListener(new OnCheckedChangeListener() {
						public void onCheckedChanged(CompoundButton buttonView, boolean isChecked) {
							mPrefs.edit().putBoolean(Gamepad.pref_mic, isChecked).apply();
							if (isChecked && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
									ActivityCompat.requestPermissions(getActivity(),
											new String[] {
													Manifest.permission.RECORD_AUDIO
											},
											PERMISSION_REQUEST);
							}
						}
					});
		} else {
			micPluggedIntoController.setEnabled(false);
		}

		Button buttonKeycodeEditor = (Button) getView().findViewById(
				R.id.buttonKeycodeEditor);
		buttonKeycodeEditor.setOnClickListener(new View.OnClickListener() {
			public void onClick(View v) {
				InputModFragment inputModFrag = new InputModFragment();
				getActivity()
						.getSupportFragmentManager().beginTransaction()
						.replace(R.id.fragment_container, inputModFrag, "INPUT_MOD_FRAG")
						.addToBackStack(null).commit();
			}
		});

		Button buttonSelectControllerPlayer1 = (Button) getView()
				.findViewById(R.id.buttonSelectControllerPlayer1);
		buttonSelectControllerPlayer1
				.setOnClickListener(new View.OnClickListener() {
					public void onClick(View v) {
						selectController(1);
					}
				});
		Button buttonSelectControllerPlayer2 = (Button) getView()
				.findViewById(R.id.buttonSelectControllerPlayer2);
		buttonSelectControllerPlayer2
				.setOnClickListener(new View.OnClickListener() {
					public void onClick(View v) {
						selectController(2);
					}
				});
		Button buttonSelectControllerPlayer3 = (Button) getView()
				.findViewById(R.id.buttonSelectControllerPlayer3);
		buttonSelectControllerPlayer3
				.setOnClickListener(new View.OnClickListener() {
					public void onClick(View v) {
						selectController(3);
					}
				});
		Button buttonSelectControllerPlayer4 = (Button) getView()
				.findViewById(R.id.buttonSelectControllerPlayer4);
		buttonSelectControllerPlayer4
				.setOnClickListener(new View.OnClickListener() {
					public void onClick(View v) {
						selectController(4);
					}
				});

		Button buttonRemoveControllerPlayer1 = (Button) getView()
				.findViewById(R.id.buttonRemoveControllerPlayer1);
		buttonRemoveControllerPlayer1
				.setOnClickListener(new View.OnClickListener() {
					public void onClick(View v) {
						removeController(1);
					}
				});

		Button buttonRemoveControllerPlayer2 = (Button) getView()
				.findViewById(R.id.buttonRemoveControllerPlayer2);
		buttonRemoveControllerPlayer2
				.setOnClickListener(new View.OnClickListener() {
					public void onClick(View v) {
						removeController(2);
					}
				});

		Button buttonRemoveControllerPlayer3 = (Button) getView()
				.findViewById(R.id.buttonRemoveControllerPlayer3);
		buttonRemoveControllerPlayer3
				.setOnClickListener(new View.OnClickListener() {
					public void onClick(View v) {
						removeController(3);
					}
				});

		Button buttonRemoveControllerPlayer4 = (Button) getView()
				.findViewById(R.id.buttonRemoveControllerPlayer4);
		buttonRemoveControllerPlayer4
				.setOnClickListener(new View.OnClickListener() {
					public void onClick(View v) {
						removeController(4);
					}
				});

		updateControllers();

		updateVibration();
	}

	private boolean isBIOSAvailable() {
		String home_directory = mPrefs.getString(Config.pref_home,
				Environment.getExternalStorageDirectory().getAbsolutePath());
		return new File(home_directory, "data/dc_flash.bin").exists()
				|| mPrefs.getBoolean(Emulator.pref_usereios, false);
	}

	private void updateVibration() {
		boolean touchVibrationEnabled = mPrefs.getBoolean(Config.pref_touchvibe, true);
		switchTouchVibrationEnabled.setChecked(touchVibrationEnabled);
	}

	private void updateControllers() {
		String deviceDescriptorPlayer1 = mPrefs.getString(Gamepad.pref_player1, null);
		String deviceDescriptorPlayer2 = mPrefs.getString(Gamepad.pref_player2, null);
		String deviceDescriptorPlayer3 = mPrefs.getString(Gamepad.pref_player3, null);
		String deviceDescriptorPlayer4 = mPrefs.getString(Gamepad.pref_player4, null);

		String labelPlayer1 = null, labelPlayer2 = null, labelPlayer3 = null, labelPlayer4 = null;

		for (int devideId : InputDevice.getDeviceIds()) {
			InputDevice dev = InputDevice.getDevice(devideId);
			String descriptor = dev.getDescriptor();

			if (descriptor != null) {
				if (descriptor.equals(deviceDescriptorPlayer1))
					labelPlayer1 = dev.getName() + " (" + descriptor + ")";
				else if (descriptor.equals(deviceDescriptorPlayer2))
					labelPlayer2 = dev.getName() + " (" + descriptor + ")";
				else if (descriptor.equals(deviceDescriptorPlayer3))
					labelPlayer3 = dev.getName() + " (" + descriptor + ")";
				else if (descriptor.equals(deviceDescriptorPlayer4))
					labelPlayer4 = dev.getName() + " (" + descriptor + ")";
			}
		}

		TextView textViewDeviceDescriptorPlayer1 = (TextView) getView()
				.findViewById(R.id.textViewDeviceDescriptorPlayer1);
		Button buttonRemoveControllerPlayer1 = (Button) getView().findViewById(
				R.id.buttonRemoveControllerPlayer1);
		if (labelPlayer1 != null) {
			textViewDeviceDescriptorPlayer1.setText(labelPlayer1);
			buttonRemoveControllerPlayer1.setEnabled(true);
		} else {
			if (deviceDescriptorPlayer1 != null) {
				textViewDeviceDescriptorPlayer1.setText(getString(R.string.controller_not_connected,
						"(" + deviceDescriptorPlayer1 + ")"));
				buttonRemoveControllerPlayer1.setEnabled(true);
			} else {
				textViewDeviceDescriptorPlayer1
						.setText(R.string.controller_none_selected);
				buttonRemoveControllerPlayer1.setEnabled(false);
			}
		}

		TextView textViewDeviceDescriptorPlayer2 = (TextView) getView()
				.findViewById(R.id.textViewDeviceDescriptorPlayer2);
		Button buttonRemoveControllerPlayer2 = (Button) getView().findViewById(
				R.id.buttonRemoveControllerPlayer2);
		if (labelPlayer2 != null) {
			textViewDeviceDescriptorPlayer2.setText(labelPlayer2);
			buttonRemoveControllerPlayer2.setEnabled(true);
		} else {
			if (deviceDescriptorPlayer2 != null) {
				textViewDeviceDescriptorPlayer2.setText(getString(R.string.controller_not_connected,
						"(" + deviceDescriptorPlayer2 + ")"));
				buttonRemoveControllerPlayer2.setEnabled(true);
			} else {
				textViewDeviceDescriptorPlayer2
						.setText(R.string.controller_none_selected);
				buttonRemoveControllerPlayer2.setEnabled(false);
			}
		}

		String[] periphs = getResources().getStringArray(R.array.peripherals);

		Spinner p2periph1spnr = (Spinner) getView().findViewById(R.id.spnr_player2_periph1);
		ArrayAdapter<String> p2periph1Adapter = new ArrayAdapter<>(
				getActivity(), R.layout.spinner_selected, periphs);
		p2periph1Adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
		p2periph1spnr.setAdapter(p2periph1Adapter);

		p2periph1spnr.setSelection(mPrefs.getInt(
				Gamepad.p2_peripheral + 1, 0), true);

		p2periph1spnr.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {

			public void onItemSelected(AdapterView<?> parent, View view, int pos, long id) {
				mPrefs.edit().putInt(Gamepad.p2_peripheral + 1, pos).apply();
			}

			public void onNothingSelected(AdapterView<?> arg0) {

			}
		});

		Spinner p2periph2spnr = (Spinner) getView().findViewById(R.id.spnr_player2_periph2);
		ArrayAdapter<String> p2periph2Adapter = new ArrayAdapter<>(
				getActivity(), R.layout.spinner_selected, periphs);
		p2periph2Adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
		p2periph2spnr.setAdapter(p2periph2Adapter);

		p2periph2spnr.setSelection(mPrefs.getInt(
				Gamepad.p2_peripheral + 2, 0), true);

		p2periph2spnr.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {

			public void onItemSelected(AdapterView<?> parent, View view, int pos, long id) {
				mPrefs.edit().putInt(Gamepad.p2_peripheral + 2, pos).apply();
			}

			public void onNothingSelected(AdapterView<?> arg0) {

			}
		});

		TextView textViewDeviceDescriptorPlayer3 = (TextView) getView()
				.findViewById(R.id.textViewDeviceDescriptorPlayer3);
		Button buttonRemoveControllerPlayer3 = (Button) getView().findViewById(
				R.id.buttonRemoveControllerPlayer3);
		if (labelPlayer3 != null) {
			textViewDeviceDescriptorPlayer3.setText(labelPlayer3);
			buttonRemoveControllerPlayer3.setEnabled(true);
		} else {
			if (deviceDescriptorPlayer3 != null) {
				textViewDeviceDescriptorPlayer3.setText(getString(R.string.controller_not_connected,
						"(" + deviceDescriptorPlayer3 + ")"));
				buttonRemoveControllerPlayer3.setEnabled(true);
			} else {
				textViewDeviceDescriptorPlayer3
						.setText(R.string.controller_none_selected);
				buttonRemoveControllerPlayer3.setEnabled(false);
			}
		}

		Spinner p3periph1spnr = (Spinner) getView().findViewById(R.id.spnr_player3_periph1);
		ArrayAdapter<String> p3periph1Adapter = new ArrayAdapter<>(
				getActivity(), R.layout.spinner_selected, periphs);
		p3periph1Adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
		p3periph1spnr.setAdapter(p3periph1Adapter);

		p3periph1spnr.setSelection(mPrefs.getInt(
				Gamepad.p3_peripheral + 1, 0), true);

		p3periph1spnr.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {

			public void onItemSelected(AdapterView<?> parent, View view, int pos, long id) {
				mPrefs.edit().putInt(Gamepad.p3_peripheral + 1, pos).apply();
			}

			public void onNothingSelected(AdapterView<?> arg0) {

			}
		});

		Spinner p3periph2spnr = (Spinner) getView().findViewById(R.id.spnr_player3_periph2);
		ArrayAdapter<String> p3periph2Adapter = new ArrayAdapter<>(
				getActivity(), R.layout.spinner_selected, periphs);
		p3periph2Adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
		p3periph2spnr.setAdapter(p3periph2Adapter);

		p3periph2spnr.setSelection(mPrefs.getInt(
				Gamepad.p3_peripheral + 2, 0), true);

		p3periph2spnr.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {

			public void onItemSelected(AdapterView<?> parent, View view, int pos, long id) {
				mPrefs.edit().putInt(Gamepad.p3_peripheral + 2, pos).apply();
			}

			public void onNothingSelected(AdapterView<?> arg0) {

			}
		});

		TextView textViewDeviceDescriptorPlayer4 = (TextView) getView()
				.findViewById(R.id.textViewDeviceDescriptorPlayer4);
		Button buttonRemoveControllerPlayer4 = (Button) getView().findViewById(
				R.id.buttonRemoveControllerPlayer4);
		if (labelPlayer4 != null) {
			textViewDeviceDescriptorPlayer4.setText(labelPlayer4);
			buttonRemoveControllerPlayer4.setEnabled(true);
		} else {
			if (deviceDescriptorPlayer4 != null) {
				textViewDeviceDescriptorPlayer4.setText(getString(R.string.controller_not_connected,
						"(" + deviceDescriptorPlayer4 + ")"));
				buttonRemoveControllerPlayer4.setEnabled(true);
			} else {
				textViewDeviceDescriptorPlayer4
						.setText(R.string.controller_none_selected);
				buttonRemoveControllerPlayer4.setEnabled(false);
			}
		}

		Spinner p4periph1spnr = (Spinner) getView().findViewById(R.id.spnr_player4_periph1);
		ArrayAdapter<String> p4periph1Adapter = new ArrayAdapter<>(
				getActivity(), R.layout.spinner_selected, periphs);
		p4periph1Adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
		p4periph1spnr.setAdapter(p4periph1Adapter);

		String p4periph1 = String.valueOf(mPrefs.getInt(Gamepad.p4_peripheral + 1, 0));
		p4periph1spnr.setSelection(p2periph2Adapter.getPosition(p4periph1), true);

		p4periph1spnr.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {

			public void onItemSelected(AdapterView<?> parent, View view, int pos, long id) {
				mPrefs.edit().putInt(Gamepad.p4_peripheral + 1, pos).apply();
			}

			public void onNothingSelected(AdapterView<?> arg0) {

			}
		});

		Spinner p4periph2spnr = (Spinner) getView().findViewById(R.id.spnr_player4_periph2);
		ArrayAdapter<String> p4periph2Adapter = new ArrayAdapter<>(
				getActivity(), R.layout.spinner_selected, periphs);
		p4periph2Adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
		p4periph2spnr.setAdapter(p4periph2Adapter);

		String p4periph2 = String.valueOf(mPrefs.getInt(Gamepad.p4_peripheral + 2, 0));
		p4periph2spnr.setSelection(p2periph2Adapter.getPosition(p4periph2), true);

		p4periph2spnr.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {

			public void onItemSelected(AdapterView<?> parent, View view, int pos, long id) {
				mPrefs.edit().putInt(Gamepad.p4_peripheral + 2, pos).apply();
			}

			public void onNothingSelected(AdapterView<?> arg0) {

			}
		});
	}

	private void selectController(int playerNum) {
		listenForButton = playerNum;

		AlertDialog.Builder builder = new AlertDialog.Builder(getActivity());
		builder.setTitle(R.string.select_controller_title);
		builder.setMessage(getString(R.string.select_controller_message,
				String.valueOf(listenForButton)));
		builder.setPositiveButton(R.string.cancel,
				new DialogInterface.OnClickListener() {
					public void onClick(DialogInterface dialog, int which) {
						listenForButton = 0;
						dialog.dismiss();
					}
				});
		builder.setNegativeButton(R.string.manual,
				new DialogInterface.OnClickListener() {
					public void onClick(DialogInterface dialog, int which) {
						InputModFragment inputModFrag = new InputModFragment();
						Bundle args = new Bundle();
						args.putInt("portNumber", listenForButton - 1);
						inputModFrag.setArguments(args);
						listenForButton = 0;
						getActivity()
								.getSupportFragmentManager()
								.beginTransaction()
								.replace(R.id.fragment_container, inputModFrag,
										"INPUT_MOD_FRAG").addToBackStack(null)
								.commit();
						dialog.dismiss();
					}
				});
		builder.setOnKeyListener(new Dialog.OnKeyListener() {
			public boolean onKey(DialogInterface dialog, int keyCode,
								 KeyEvent event) {
				return mapDevice(keyCode, event);
			}
		});
		alertDialogSelectController = builder.create();
		alertDialogSelectController.show();
	}

	private boolean mapDevice(int keyCode, KeyEvent event) {
		if (keyCode == KeyEvent.KEYCODE_MENU
				|| keyCode == KeyEvent.KEYCODE_VOLUME_UP
				|| keyCode == KeyEvent.KEYCODE_VOLUME_DOWN)
			return false;
		if (keyCode == KeyEvent.KEYCODE_BACK)
			return false;

		String descriptor = InputDevice.getDevice(event.getDeviceId()).getDescriptor();

		if (descriptor == null)
			return false;

		String deviceDescriptorPlayer1 = mPrefs.getString(Gamepad.pref_player1, null);
		String deviceDescriptorPlayer2 = mPrefs.getString(Gamepad.pref_player2, null);
		String deviceDescriptorPlayer3 = mPrefs.getString(Gamepad.pref_player3, null);
		String deviceDescriptorPlayer4 = mPrefs.getString(Gamepad.pref_player4, null);

		if (descriptor.equals(deviceDescriptorPlayer1)
				|| descriptor.equals(deviceDescriptorPlayer2)
				|| descriptor.equals(deviceDescriptorPlayer3)
				|| descriptor.equals(deviceDescriptorPlayer4)) {
			Toast.makeText(getActivity(), R.string.controller_already_in_use,
					Toast.LENGTH_SHORT).show();
			return true;
		}

		switch (listenForButton) {
			case 0:
				return false;
			case 1:
				mPrefs.edit().putString(Gamepad.pref_player1, descriptor).apply();
				break;
			case 2:
				mPrefs.edit().putString(Gamepad.pref_player2, descriptor).apply();
				break;
			case 3:
				mPrefs.edit().putString(Gamepad.pref_player3, descriptor).apply();
				break;
			case 4:
				mPrefs.edit().putString(Gamepad.pref_player4, descriptor).apply();
				break;
		}

		Log.d("New port " + listenForButton + " controller:", descriptor);

		listenForButton = 0;
		alertDialogSelectController.cancel();
		updateControllers();

		return true;
	}

	private void removeController(int playerNum) {
		switch (playerNum) {
			case 1:
				mPrefs.edit().putString(Gamepad.pref_player1, null).apply();
				break;
			case 2:
				mPrefs.edit().putString(Gamepad.pref_player2, null).apply();
				break;
			case 3:
				mPrefs.edit().putString(Gamepad.pref_player3, null).apply();
				break;
			case 4:
				mPrefs.edit().putString(Gamepad.pref_player4, null).apply();
				break;
		}

		updateControllers();
	}
}
