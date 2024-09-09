
#ifndef _UISCREEN_H
#define _UISCREEN_H


typedef int (*ScreenMsgFuncT)(Uint32 Type, Uint32 Parm1, void *Parm2);

extern void MainLoopRender();

class CScreen
{
private:
	ScreenMsgFuncT 	m_pMsgFunc;

public:
	CScreen() {m_pMsgFunc =NULL;}
	virtual ~CScreen() {}

	virtual void Activate() {}
	virtual void Deactivate() {}

	virtual void Draw() {}
	virtual void Process() {}
	virtual void Input(Uint32 Buttons, Uint32 Trigger) {}

	void ForceDraw()
	{
		MainLoopRender();
	}

	int SendMessage(Uint32 Type, Uint32 Parm1, void *Parm2)
	{
		if (m_pMsgFunc)
		{
			return m_pMsgFunc(Type, Parm1, Parm2);
		}
		return 0;
	}
	void SetMsgFunc(ScreenMsgFuncT pFunc) {m_pMsgFunc = pFunc;}
};

#endif
