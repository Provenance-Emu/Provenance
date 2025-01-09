#ifndef CONFIGDIALOG_H
#define CONFIGDIALOG_H

#include <QDialog>
#include <QTreeWidgetItem>

namespace Ui {
class ConfigDialog;
}

class QAbstractButton;
class ConfigDialog : public QDialog
{
	Q_OBJECT

public:
	explicit ConfigDialog(QWidget *parent = Q_NULLPTR, Qt::WindowFlags f = Qt::WindowFlags());
	~ConfigDialog();

	void setIniPath(const QString & _strIniPath);
	void setRomName(const char * _romName);
	void setTitle();
	bool isAccepted() const { return m_accepted; }

public Q_SLOTS:
	virtual void accept();

private slots:
	void on_PickFontColorButton_clicked();

	void on_buttonBox_clicked(QAbstractButton *button);

	void on_fullScreenResolutionComboBox_currentIndexChanged(int index);

	void on_texPackPathButton_clicked();

	void on_windowedResolutionComboBox_currentIndexChanged(int index);

	void on_windowedResolutionComboBox_currentTextChanged(QString text);

	void on_overscanCheckBox_toggled(bool checked);

	void on_frameBufferCheckBox_toggled(bool checked);

	void on_aliasingSlider_valueChanged(int value);

	void on_fontTreeWidget_currentItemChanged(QTreeWidgetItem *current, QTreeWidgetItem *previous);

	void on_fontSizeSpinBox_valueChanged(int value);

	void on_tabWidget_currentChanged(int tab);

	void on_texCachePathButton_clicked();

	void on_texDumpPathButton_clicked();

	void on_profilesComboBox_currentIndexChanged(const QString &arg1);

	void on_addProfilePushButton_clicked();

	void on_removeProfilePushButton_clicked();

	void on_fxaaCheckBox_toggled(bool checked);

	void on_n64DepthCompareCheckBox_toggled(bool checked);

private:
	void _init();
	void _getTranslations(QStringList & _translationFiles) const;

	Ui::ConfigDialog *ui;
	QFont m_font;
	QColor m_color;
	bool m_accepted;
	bool m_fontsInited;
	QString m_strIniPath;
	const char * m_romName;
};

#endif // CONFIGDIALOG_H
