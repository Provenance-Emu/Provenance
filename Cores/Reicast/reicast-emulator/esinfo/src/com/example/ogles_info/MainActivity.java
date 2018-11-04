package com.example.ogles_info;

import javax.microedition.khronos.egl.EGL10;
import javax.microedition.khronos.egl.EGL11;
import javax.microedition.khronos.egl.EGLConfig;
import javax.microedition.khronos.egl.EGLContext;
import javax.microedition.khronos.egl.EGLDisplay;
import javax.microedition.khronos.opengles.GL11;

import android.opengl.GLES20;
import android.os.Bundle;
import android.app.Activity;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.LinearLayout;
import android.widget.ListView;
import android.widget.TextView;
import android.widget.ToggleButton;
import android.support.v4.app.NavUtils;
import android.widget.Toast;

public class MainActivity extends Activity {

	LinearLayout lv;
	ToggleButton tbn_alpha;
	ToggleButton tbn_24bits;
	ToggleButton tbn_depth;
	ToggleButton tbn_stencil;
	
    @Override
    public void onCreate(Bundle savedInstanceState) {
    	final boolean jnt = jnitest.test()!=0;
    	
    	super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        lv = (LinearLayout)findViewById(R.id.caps_list);
        
        Toast.makeText(getApplicationContext(), jnt ? "jni test passed" : "jni test failed", Toast.LENGTH_SHORT).show();
        
        OnClickListener ocl =new OnClickListener() { public void onClick(View v) { MainActivity.this.populate_list(jnt); } };
        
        tbn_24bits=(ToggleButton)findViewById(R.id.tbn_24bits);
        tbn_depth=(ToggleButton)findViewById(R.id.tbn_depth);
        tbn_stencil=(ToggleButton)findViewById(R.id.tbn_stencil);
        tbn_alpha=(ToggleButton)findViewById(R.id.tbn_alpha);
        
        tbn_24bits.setOnClickListener(ocl);
        tbn_depth.setOnClickListener(ocl);
        tbn_stencil.setOnClickListener(ocl);
        tbn_alpha.setOnClickListener(ocl);
        
        populate_list(jnt);
    }
    
    void add_string(String s)
    {
    	TextView tv = new TextView(this);
    	tv.setText(s);
    	
    	lv.addView(tv);
    }
    void populate_list(boolean jnt)
    {
        lv.removeAllViews();
        
        add_string("MMAP ALLOC TEST: " + (jnt ? "PASSED":"FAILED"));
        add_string("BOARD: " + android.os.Build.BOARD);
        add_string("BOOTLOADER: " + android.os.Build.BOOTLOADER);
        add_string("BRAND: " + android.os.Build.BRAND);
        add_string("CPU_ABI: " + android.os.Build.CPU_ABI);
        add_string("CPU_ABI2: " + android.os.Build.CPU_ABI2);
        add_string("DEVICE: " + android.os.Build.DEVICE);
        add_string("DISPLAY: " + android.os.Build.DISPLAY);
        add_string("FINGERPRINT: " + android.os.Build.FINGERPRINT);
        add_string("HARDWARE: " + android.os.Build.HARDWARE);
        add_string("HOST: " + android.os.Build.HOST);
        add_string("ID: " + android.os.Build.ID);
        add_string("MANUFACTURER: " + android.os.Build.MANUFACTURER);
        add_string("MODEL: " + android.os.Build.MODEL);
        add_string("PRODUCT: " + android.os.Build.PRODUCT);
        //add_string("SERIAL: " + android.os.Build.SERIAL);
        add_string("TAGS: " + android.os.Build.TAGS);
        add_string("TYPE: " + android.os.Build.TYPE);
        add_string("CODENAME: " + android.os.Build.VERSION.CODENAME);
        add_string("RELEASE: " + android.os.Build.VERSION.RELEASE);
        add_string("INCREMENTAL: " + android.os.Build.VERSION.INCREMENTAL);
        add_string("SDK: " + android.os.Build.VERSION.SDK_INT);
        
        EGL10 e = (EGL10)EGLContext.getEGL();
        //EGL10 e = (EGL10)GLES20.glGetString(name)
        
        EGLConfig[] cfgs = new EGLConfig[1000];
        
        int[] cfg_cnt= new int[1];
        EGLDisplay disp=e.eglGetDisplay(EGL10.EGL_DEFAULT_DISPLAY);
        
        int[] version = new int[2];
        e.eglInitialize(disp, version);
        
        e.eglGetConfigs(disp, cfgs, cfgs.length, cfg_cnt);
        
        for (int i=0;i<cfg_cnt[0];i++)
        {
        	EGLConfig cfg=cfgs[i];
        	
        	int[] temp= new int[1];
        	
        	e.eglGetConfigAttrib(disp, cfg, EGL10.EGL_RENDERABLE_TYPE, temp);
        	
        	
        	
        	if (0!= (temp[0]&4) )
        	{
        		String s="";
        		
        		e.eglGetConfigAttrib(disp, cfg, EGL10.EGL_BUFFER_SIZE, temp);
        		if (tbn_24bits.isChecked() && temp[0]<24)
        			continue;
        		
        		e.eglGetConfigAttrib(disp, cfg, EGL10.EGL_RED_SIZE, temp);
        		s+="R" + temp[0];
        		
        		e.eglGetConfigAttrib(disp, cfg, EGL10.EGL_GREEN_SIZE, temp);
        		s+="G" + temp[0];
        		
        		e.eglGetConfigAttrib(disp, cfg, EGL10.EGL_BLUE_SIZE, temp);
        		s+="B" + temp[0];
        		
        		e.eglGetConfigAttrib(disp, cfg, EGL10.EGL_ALPHA_SIZE, temp);
        		if (tbn_alpha.isChecked() && temp[0]==0)
        			continue;
        		s+="A" + temp[0];
        		
        		s+=" ";
        		
        		e.eglGetConfigAttrib(disp, cfg, EGL10.EGL_DEPTH_SIZE, temp);
        		s+="D" + temp[0];
        		
        		if (tbn_depth.isChecked() && temp[0]==0)
        			continue;
        		
        		
        		e.eglGetConfigAttrib(disp, cfg, EGL10.EGL_STENCIL_SIZE, temp);
        		s+="S" + temp[0];
        		
        		if (tbn_stencil.isChecked() && temp[0]==0)
        			continue;
        		
        		add_string(s);
        	}
        }
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        return true;
    }

    
}
