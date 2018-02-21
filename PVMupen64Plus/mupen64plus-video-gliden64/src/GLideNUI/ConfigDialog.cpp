#include <QDir>
#include <QStandardPaths>
#include <QFileDialog>
#include <QFont>
#include <QFontDatabase>
#include <QColorDialog>
#include <QAbstractButton>
#include <QMessageBox>
#include <QCursor>
#include <QRegExpValidator>

#include "../Config.h"
#include "../DebugDump.h"
#include "ui_configDialog.h"
#include "Settings.h"
#include "ConfigDialog.h"
#include "FullscreenResolutions.h"

static
struct
{
	unsigned short width, height;
	const char *description;
} WindowedModes[] = {
	{ 320, 240, "320 x 240" },
	{ 400, 300, "400 x 300" },
	{ 480, 360, "480 x 360" },
	{ 640, 480, "640 x 480" },
	{ 800, 600, "800 x 600" },
	{ 960, 720, "960 x 720" },
	{ 1024, 768, "1024 x 768" },
	{ 1152, 864, "1152 x 864" },
	{ 1280, 960, "1280 x 960" },
	{ 1280, 1024, "1280 x 1024" },
	{ 1440, 1080, "1440 x 1080" },
	{ 1600, 1024, "1600 x 1024" },
	{ 1600, 1200, "1600 x 1200" }
};
static
const unsigned int numWindowedModes = sizeof(WindowedModes) / sizeof(WindowedModes[0]);

static
u32 pow2(u32 dim)
{
	if (dim == 0)
		return 0;

	return (1<<dim);
}

static
u32 powof(u32 dim)
{
	if (dim == 0)
		return 0;

	u32 num = 2;
	u32 i = 1;

	while (num < dim) {
		num <<= 1;
		i++;
	}

	return i;
}


void ConfigDialog::_init()
{
	// Video settings
	QStringList windowedModesList;
	int windowedModesCurrent = -1;
	for (unsigned int i = 0; i < numWindowedModes; ++i) {
		windowedModesList.append(WindowedModes[i].description);
		if (WindowedModes[i].width == config.video.windowedWidth &&
			WindowedModes[i].height == config.video.windowedHeight)
			windowedModesCurrent = i;
	}
	ui->windowedResolutionComboBox->insertItems(0, windowedModesList);
	if (windowedModesCurrent > -1)
		ui->windowedResolutionComboBox->setCurrentIndex(windowedModesCurrent);
	else
		ui->windowedResolutionComboBox->setCurrentText(
			QString::number(config.video.windowedWidth) + " x " +
			QString::number(config.video.windowedHeight)
		);

	// matches w x h where w is 300-7999 and h is 200-3999, spaces around x optional
	QRegExp windowedRegExp("([3-9][0-9]{2}|[1-7][0-9]{3}) ?x ?([2-9][0-9]{2}|[1-3][0-9]{3})");
	QValidator *windowedValidator = new QRegExpValidator(windowedRegExp, this);
	ui->windowedResolutionComboBox->setValidator(windowedValidator);

	ui->cropImageComboBox->setCurrentIndex(config.video.cropMode);
	ui->cropImageWidthSpinBox->setValue(config.video.cropWidth);
	ui->cropImageHeightSpinBox->setValue(config.video.cropHeight);
	ui->cropImageCustomFrame->setVisible(config.video.cropMode == Config::cmCustom);

	QStringList fullscreenModesList, fullscreenRatesList;
	int fullscreenMode, fullscreenRate;
	fillFullscreenResolutionsList(fullscreenModesList, fullscreenMode, fullscreenRatesList, fullscreenRate);
	ui->fullScreenResolutionComboBox->insertItems(0, fullscreenModesList);
	ui->fullScreenResolutionComboBox->setCurrentIndex(fullscreenMode);
	ui->fullScreenRefreshRateComboBox->setCurrentIndex(fullscreenRate);

	ui->aliasingSlider->setValue(powof(config.video.multisampling));
	ui->aliasingLabelVal->setText(QString::number(config.video.multisampling));
	ui->anisotropicSlider->setValue(config.texture.maxAnisotropy);
	ui->vSyncCheckBox->setChecked(config.video.verticalSync != 0);

	switch (config.texture.bilinearMode) {
	case BILINEAR_3POINT:
		ui->blnr3PointRadioButton->setChecked(true);
		break;
	case BILINEAR_STANDARD:
		ui->blnrStandardRadioButton->setChecked(true);
		break;
	}

	switch (config.texture.screenShotFormat) {
	case 0:
		ui->pngRadioButton->setChecked(true);
		break;
	case 1:
		ui->jpegRadioButton->setChecked(true);
		break;
	}

	// Emulation settings
	ui->emulateLodCheckBox->setChecked(config.generalEmulation.enableLOD != 0);
	ui->emulateNoiseCheckBox->setChecked(config.generalEmulation.enableNoise != 0);
	ui->enableHWLightingCheckBox->setChecked(config.generalEmulation.enableHWLighting != 0);
	ui->enableShadersStorageCheckBox->setChecked(config.generalEmulation.enableShadersStorage != 0);
	ui->customSettingsCheckBox->setChecked(config.generalEmulation.enableCustomSettings != 0);
	switch (config.generalEmulation.correctTexrectCoords) {
	case Config::tcDisable:
		ui->fixTexrectDisableRadioButton->setChecked(true);
		break;
	case Config::tcSmart:
		ui->fixTexrectSmartRadioButton->setChecked(true);
		break;
	case Config::tcForce:
		ui->fixTexrectForceRadioButton->setChecked(true);
		break;
	}
	ui->nativeRes2D_checkBox->toggle();
	ui->nativeRes2D_checkBox->setChecked(config.generalEmulation.enableNativeResTexrects != 0);

	ui->gammaCorrectionCheckBox->toggle();
	ui->gammaCorrectionCheckBox->setChecked(config.gammaCorrection.force != 0);
	ui->gammaLevelSpinBox->setValue(config.gammaCorrection.level);

	ui->frameBufferSwapComboBox->setCurrentIndex(config.frameBufferEmulation.bufferSwapMode);

	ui->fbInfoEnableCheckBox->toggle();
	ui->fbInfoEnableCheckBox->setChecked(config.frameBufferEmulation.fbInfoDisabled == 0);

	ui->frameBufferCheckBox->toggle();
	const bool fbEmulationEnabled = config.frameBufferEmulation.enable != 0;
	ui->frameBufferCheckBox->setChecked(fbEmulationEnabled);
	ui->frameBufferInfoFrame->setVisible(!fbEmulationEnabled);
	ui->frameBufferInfoFrame2->setVisible(!fbEmulationEnabled);

	ui->copyColorBufferComboBox->setCurrentIndex(config.frameBufferEmulation.copyToRDRAM);
	ui->copyDepthBufferComboBox->setCurrentIndex(config.frameBufferEmulation.copyDepthToRDRAM);
	ui->RenderFBCheckBox->setChecked(config.frameBufferEmulation.copyFromRDRAM != 0);
	ui->n64DepthCompareCheckBox->toggle();
	ui->n64DepthCompareCheckBox->setChecked(config.frameBufferEmulation.N64DepthCompare != 0);

	switch (config.frameBufferEmulation.aspect) {
	case Config::aStretch:
		ui->aspectStretchRadioButton->setChecked(true);
		break;
	case Config::a43:
		ui->aspect43RadioButton->setChecked(true);
		break;
	case Config::a169:
		ui->aspect169RadioButton->setChecked(true);
		break;
	case Config::aAdjust:
		ui->aspectAdjustRadioButton->setChecked(true);
		break;
	}

	ui->resolutionFactorSlider->valueChanged(2);
	ui->factor0xRadioButton->toggle();
	ui->factor1xRadioButton->toggle();
	ui->factorXxRadioButton->toggle();
	switch (config.frameBufferEmulation.nativeResFactor) {
	case 0:
		ui->factor0xRadioButton->setChecked(true);
		break;
	case 1:
		ui->factor1xRadioButton->setChecked(true);
		break;
	default:
		ui->factorXxRadioButton->setChecked(true);
		ui->resolutionFactorSlider->setValue(config.frameBufferEmulation.nativeResFactor);
		break;
	}

	ui->copyAuxBuffersCheckBox->setChecked(config.frameBufferEmulation.copyAuxToRDRAM != 0);

	ui->readColorChunkCheckBox->setChecked(config.frameBufferEmulation.fbInfoReadColorChunk != 0);
	ui->readColorChunkCheckBox->setEnabled(fbEmulationEnabled && config.frameBufferEmulation.fbInfoDisabled == 0);
	ui->readDepthChunkCheckBox->setChecked(config.frameBufferEmulation.fbInfoReadDepthChunk != 0);
	ui->readDepthChunkCheckBox->setEnabled(fbEmulationEnabled && config.frameBufferEmulation.fbInfoDisabled == 0);

	// Texture filter settings
	ui->filterComboBox->setCurrentIndex(config.textureFilter.txFilterMode);
	ui->enhancementComboBox->setCurrentIndex(config.textureFilter.txEnhancementMode);

	ui->textureFilterCacheSpinBox->setValue(config.textureFilter.txCacheSize / gc_uMegabyte);
	ui->deposterizeCheckBox->setChecked(config.textureFilter.txDeposterize != 0);
	ui->ignoreBackgroundsCheckBox->setChecked(config.textureFilter.txFilterIgnoreBG != 0);

	ui->texturePackOnCheckBox->toggle();
	ui->texturePackOnCheckBox->setChecked(config.textureFilter.txHiresEnable != 0);
	ui->alphaChannelCheckBox->setChecked(config.textureFilter.txHiresFullAlphaChannel != 0);
	ui->alternativeCRCCheckBox->setChecked(config.textureFilter.txHresAltCRC != 0);
	ui->textureDumpCheckBox->setChecked(config.textureFilter.txDump != 0);
	ui->force16bppCheckBox->setChecked(config.textureFilter.txForce16bpp != 0);
	ui->compressCacheCheckBox->setChecked(config.textureFilter.txCacheCompression != 0);
	ui->saveTextureCacheCheckBox->setChecked(config.textureFilter.txSaveCache != 0);

	ui->txPathLabel->setText(QString::fromWCharArray(config.textureFilter.txPath));
	ui->txCachePathLabel->setText(QString::fromWCharArray(config.textureFilter.txCachePath));
	ui->txDumpPathLabel->setText(QString::fromWCharArray(config.textureFilter.txDumpPath));

	// OSD settings
	QString fontName(config.font.name.c_str());
	ui->fontLineEdit->setText(fontName);
	m_font = QFont(fontName.left(fontName.indexOf(".ttf")));
	m_font.setPixelSize(config.font.size);

	ui->fontLineEdit->setHidden(true);

	ui->fontSizeSpinBox->setValue(config.font.size);

	m_color = QColor(config.font.color[0], config.font.color[1], config.font.color[2]);
	QPalette palette;
	palette.setColor(QPalette::WindowText, m_color);
	palette.setColor(QPalette::Window, Qt::black);
	ui->fontPreviewLabel->setAutoFillBackground(true);
	ui->fontPreviewLabel->setPalette(palette);
	ui->PickFontColorButton->setStyleSheet(QString("color:") + m_color.name());

	switch (config.onScreenDisplay.pos) {
	case Config::posTopLeft:
		ui->topLeftPushButton->setChecked(true);
		break;
	case Config::posTopCenter:
		ui->topPushButton->setChecked(true);
		break;
	case Config::posTopRight:
		ui->topRightPushButton->setChecked(true);
		break;
	case Config::posBottomLeft:
		ui->bottomLeftPushButton->setChecked(true);
		break;
	case Config::posBottomCenter:
		ui->bottomPushButton->setChecked(true);
		break;
	case Config::posBottomRight:
		ui->bottomRightPushButton->setChecked(true);
		break;
	}

	ui->fpsCheckBox->setChecked(config.onScreenDisplay.fps != 0);
	ui->visCheckBox->setChecked(config.onScreenDisplay.vis != 0);
	ui->percentCheckBox->setChecked(config.onScreenDisplay.percent != 0);

	// Buttons
	ui->buttonBox->button(QDialogButtonBox::Ok)->setText(tr("OK"));
	ui->buttonBox->button(QDialogButtonBox::Cancel)->setText(tr("Cancel"));
	ui->buttonBox->button(QDialogButtonBox::RestoreDefaults)->setText(tr("Restore Defaults"));

	ui->dumpLowCheckBox->setChecked((config.debug.dumpMode & DEBUG_LOW) != 0);
	ui->dumpNormalCheckBox->setChecked((config.debug.dumpMode & DEBUG_NORMAL) != 0);
	ui->dumpDetailCheckBox->setChecked((config.debug.dumpMode & DEBUG_DETAIL) != 0);

#ifndef DEBUG_DUMP
	for (int i = 0; i < ui->tabWidget->count(); ++i) {
		if (tr("Debug") == ui->tabWidget->tabText(i)) {
			ui->tabWidget->removeTab(i);
			break;
		}
	}
#endif
}

void ConfigDialog::_getTranslations(QStringList & _translationFiles) const
{
	QDir pluginFolder(m_strIniPath);
	QStringList nameFilters("gliden64_*.qm");
	_translationFiles = pluginFolder.entryList(nameFilters, QDir::Files, QDir::Name);
}


void ConfigDialog::setIniPath(const QString & _strIniPath)
{
	m_strIniPath = _strIniPath;

	QStringList translationFiles;
	_getTranslations(translationFiles);

	const QString currentTranslation = getTranslationFile();
	int listIndex = 0;
	QStringList translationLanguages("English");
	for (int i = 0; i < translationFiles.size(); ++i) {
		// get locale extracted by filename
		QString locale = translationFiles[i]; // "TranslationExample_de.qm"
		const bool bCurrent = locale == currentTranslation;
		locale.truncate(locale.lastIndexOf('.')); // "TranslationExample_de"
		locale.remove(0, locale.indexOf('_') + 1); // "de"
		QString language = QLocale(locale).nativeLanguageName();
		language = language.left(1).toUpper() + language.remove(0, 1);
		if (bCurrent) {
			listIndex = i + 1;
		}
		translationLanguages << language;
	}

	ui->translationsComboBox->insertItems(0, translationLanguages);
	ui->translationsComboBox->setCurrentIndex(listIndex);
}

ConfigDialog::ConfigDialog(QWidget *parent, Qt::WindowFlags f) :
QDialog(parent, f),
ui(new Ui::ConfigDialog),
m_accepted(false),
m_fontsInited(false)
{
	ui->setupUi(this);
	_init();
}

ConfigDialog::~ConfigDialog()
{
	delete ui;
}

void ConfigDialog::accept()
{
	m_accepted = true;

	int windowedValidatorPos = 0;
	QString currentText = ui->windowedResolutionComboBox->currentText();
	if (ui->windowedResolutionComboBox->validator()->validate(
		currentText, windowedValidatorPos
	) == QValidator::Acceptable) {
		QStringList windowedResolutionDimensions = currentText.split("x");
		config.video.windowedWidth = windowedResolutionDimensions[0].trimmed().toInt();
		config.video.windowedHeight = windowedResolutionDimensions[1].trimmed().toInt();
	}

	getFullscreenResolutions(ui->fullScreenResolutionComboBox->currentIndex(), config.video.fullscreenWidth, config.video.fullscreenHeight);
	getFullscreenRefreshRate(ui->fullScreenRefreshRateComboBox->currentIndex(), config.video.fullscreenRefresh);

	config.video.cropMode = ui->cropImageComboBox->currentIndex();
	config.video.cropWidth = ui->cropImageWidthSpinBox->value();
	config.video.cropHeight = ui->cropImageHeightSpinBox->value();

	config.video.multisampling = ui->n64DepthCompareCheckBox->isChecked() ? 0 : pow2(ui->aliasingSlider->value());
	config.texture.maxAnisotropy = ui->anisotropicSlider->value();

	if (ui->blnrStandardRadioButton->isChecked())
		config.texture.bilinearMode = BILINEAR_STANDARD;
	else if (ui->blnr3PointRadioButton->isChecked())
		config.texture.bilinearMode = BILINEAR_3POINT;

	if (ui->pngRadioButton->isChecked())
		config.texture.screenShotFormat = 0;
	else if (ui->jpegRadioButton->isChecked())
		config.texture.screenShotFormat = 1;

	const int lanuageIndex = ui->translationsComboBox->currentIndex();
	if (lanuageIndex == 0) // English
		config.translationFile.clear();
	else {
		QStringList translationFiles;
		_getTranslations(translationFiles);
		config.translationFile = translationFiles[lanuageIndex-1].toLocal8Bit().constData();
	}

	config.video.verticalSync = ui->vSyncCheckBox->isChecked() ? 1 : 0;

	// Emulation settings
	config.generalEmulation.enableLOD = ui->emulateLodCheckBox->isChecked() ? 1 : 0;
	config.generalEmulation.enableNoise = ui->emulateNoiseCheckBox->isChecked() ? 1 : 0;
	config.generalEmulation.enableHWLighting = ui->enableHWLightingCheckBox->isChecked() ? 1 : 0;
	config.generalEmulation.enableShadersStorage = ui->enableShadersStorageCheckBox->isChecked() ? 1 : 0;
	config.generalEmulation.enableCustomSettings = ui->customSettingsCheckBox->isChecked() ? 1 : 0;

	config.gammaCorrection.force = ui->gammaCorrectionCheckBox->isChecked() ? 1 : 0;
	config.gammaCorrection.level = ui->gammaLevelSpinBox->value();

	if (ui->fixTexrectDisableRadioButton->isChecked())
		config.generalEmulation.correctTexrectCoords = Config::tcDisable;
	else if (ui->fixTexrectSmartRadioButton->isChecked())
		config.generalEmulation.correctTexrectCoords = Config::tcSmart;
	else if (ui->fixTexrectForceRadioButton->isChecked())
		config.generalEmulation.correctTexrectCoords = Config::tcForce;

	config.generalEmulation.enableNativeResTexrects = ui->nativeRes2D_checkBox->isChecked() ? 1 : 0;

	config.frameBufferEmulation.enable = ui->frameBufferCheckBox->isChecked() ? 1 : 0;

	config.frameBufferEmulation.bufferSwapMode = ui->frameBufferSwapComboBox->currentIndex();
	config.frameBufferEmulation.copyToRDRAM = ui->copyColorBufferComboBox->currentIndex();
	config.frameBufferEmulation.copyDepthToRDRAM = ui->copyDepthBufferComboBox->currentIndex();
	config.frameBufferEmulation.copyFromRDRAM = ui->RenderFBCheckBox->isChecked() ? 1 : 0;

	config.frameBufferEmulation.N64DepthCompare = ui->n64DepthCompareCheckBox->isChecked() ? 1 : 0;

	if (ui->aspectStretchRadioButton->isChecked())
		config.frameBufferEmulation.aspect = Config::aStretch;
	else if (ui->aspect43RadioButton->isChecked())
		config.frameBufferEmulation.aspect = Config::a43;
	else if (ui->aspect169RadioButton->isChecked())
		config.frameBufferEmulation.aspect = Config::a169;
	else if (ui->aspectAdjustRadioButton->isChecked())
		config.frameBufferEmulation.aspect = Config::aAdjust;

	if (ui->factor0xRadioButton->isChecked())
		config.frameBufferEmulation.nativeResFactor = 0;
	else if (ui->factor1xRadioButton->isChecked())
		config.frameBufferEmulation.nativeResFactor = 1;
	else if (ui->factorXxRadioButton->isChecked())
		config.frameBufferEmulation.nativeResFactor = ui->resolutionFactorSlider->value();

	config.frameBufferEmulation.copyAuxToRDRAM = ui->copyAuxBuffersCheckBox->isChecked() ? 1 : 0;
	config.frameBufferEmulation.fbInfoDisabled = ui->fbInfoEnableCheckBox->isChecked() ? 0 : 1;
	config.frameBufferEmulation.fbInfoReadColorChunk = ui->readColorChunkCheckBox->isChecked() ? 1 : 0;
	config.frameBufferEmulation.fbInfoReadDepthChunk = ui->readDepthChunkCheckBox->isChecked() ? 1 : 0;

	// Texture filter settings
	config.textureFilter.txFilterMode = ui->filterComboBox->currentIndex();
	config.textureFilter.txEnhancementMode = ui->enhancementComboBox->currentIndex();

	config.textureFilter.txCacheSize = ui->textureFilterCacheSpinBox->value() * gc_uMegabyte;
	config.textureFilter.txDeposterize = ui->deposterizeCheckBox->isChecked() ? 1 : 0;
	config.textureFilter.txFilterIgnoreBG = ui->ignoreBackgroundsCheckBox->isChecked() ? 1 : 0;

	config.textureFilter.txHiresEnable = ui->texturePackOnCheckBox->isChecked() ? 1 : 0;
	config.textureFilter.txHiresFullAlphaChannel = ui->alphaChannelCheckBox->isChecked() ? 1 : 0;
	config.textureFilter.txHresAltCRC = ui->alternativeCRCCheckBox->isChecked() ? 1 : 0;
	config.textureFilter.txDump = ui->textureDumpCheckBox->isChecked() ? 1 : 0;

	config.textureFilter.txCacheCompression = ui->compressCacheCheckBox->isChecked() ? 1 : 0;
	config.textureFilter.txForce16bpp = ui->force16bppCheckBox->isChecked() ? 1 : 0;
	config.textureFilter.txSaveCache = ui->saveTextureCacheCheckBox->isChecked() ? 1 : 0;

	QString txPath = ui->txPathLabel->text();
	if (!txPath.isEmpty())
		config.textureFilter.txPath[txPath.toWCharArray(config.textureFilter.txPath)] = L'\0';
	QString txCachePath = ui->txCachePathLabel->text();
	if (!txPath.isEmpty())
		config.textureFilter.txCachePath[txCachePath.toWCharArray(config.textureFilter.txCachePath)] = L'\0';
	QString txDumpPath = ui->txDumpPathLabel->text();
	if (!txDumpPath.isEmpty())
		config.textureFilter.txDumpPath[txDumpPath.toWCharArray(config.textureFilter.txDumpPath)] = L'\0';

	// OSD settings
	config.font.size = ui->fontSizeSpinBox->value();
#ifdef OS_WINDOWS
	config.font.name = ui->fontLineEdit->text().toLocal8Bit().constData();
#else
	config.font.name = ui->fontLineEdit->text().toStdString();
#endif
	config.font.color[0] = m_color.red();
	config.font.color[1] = m_color.green();
	config.font.color[2] = m_color.blue();
	config.font.color[3] = m_color.alpha();
	config.font.colorf[0] = m_color.redF();
	config.font.colorf[1] = m_color.greenF();
	config.font.colorf[2] = m_color.blueF();
	config.font.colorf[3] = m_color.alphaF();


	if (ui->topLeftPushButton->isChecked())
		config.onScreenDisplay.pos = Config::posTopLeft;
	else if (ui->topPushButton->isChecked())
		config.onScreenDisplay.pos = Config::posTopCenter;
	else if (ui->topRightPushButton->isChecked())
		config.onScreenDisplay.pos = Config::posTopRight;
	else if (ui->bottomLeftPushButton->isChecked())
		config.onScreenDisplay.pos = Config::posBottomLeft;
	else if (ui->bottomPushButton->isChecked())
		config.onScreenDisplay.pos = Config::posBottomCenter;
	else if (ui->bottomRightPushButton->isChecked())
		config.onScreenDisplay.pos = Config::posBottomRight;

	config.onScreenDisplay.fps = ui->fpsCheckBox->isChecked() ? 1 : 0;
	config.onScreenDisplay.vis = ui->visCheckBox->isChecked() ? 1 : 0;
	config.onScreenDisplay.percent = ui->percentCheckBox->isChecked() ? 1 : 0;

	config.debug.dumpMode = 0;
	if (ui->dumpLowCheckBox->isChecked())
		config.debug.dumpMode |= DEBUG_LOW;
	if (ui->dumpNormalCheckBox->isChecked())
		config.debug.dumpMode |= DEBUG_NORMAL;
	if (ui->dumpDetailCheckBox->isChecked())
		config.debug.dumpMode |= DEBUG_DETAIL;

	writeSettings(m_strIniPath);

	QDialog::accept();
}

void ConfigDialog::on_PickFontColorButton_clicked()
{
	const QColor color = QColorDialog::getColor(m_color, this);

	if (!color.isValid())
		return;

	m_color = color;
	QPalette palette;
	palette.setColor(QPalette::WindowText, m_color);
	palette.setColor(QPalette::Window, Qt::black);
	ui->fontPreviewLabel->setAutoFillBackground(true);
	ui->fontPreviewLabel->setPalette(palette);
	ui->PickFontColorButton->setStyleSheet(QString("color:") + m_color.name());
}

void ConfigDialog::on_aliasingSlider_valueChanged(int value)
{
	ui->aliasingLabelVal->setText(QString::number(pow2(value)));
}

void ConfigDialog::on_buttonBox_clicked(QAbstractButton *button)
{
	if ((QPushButton *)button == ui->buttonBox->button(QDialogButtonBox::RestoreDefaults)) {
		QMessageBox msgBox(QMessageBox::Warning, tr("Restore Defaults"),
			tr("Are you sure you want to reset all settings to default?"),
			QMessageBox::RestoreDefaults | QMessageBox::Cancel, this
			);
		msgBox.setDefaultButton(QMessageBox::Cancel);
		msgBox.setButtonText(QMessageBox::RestoreDefaults, tr("Restore Defaults"));
		msgBox.setButtonText(QMessageBox::Cancel, tr("Cancel"));
		if (msgBox.exec() == QMessageBox::RestoreDefaults) {
			config.resetToDefaults();
			_init();
		}
	}
}

void ConfigDialog::on_fullScreenResolutionComboBox_currentIndexChanged(int index)
{
	QStringList fullscreenRatesList;
	int fullscreenRate;
	fillFullscreenRefreshRateList(index, fullscreenRatesList, fullscreenRate);
	ui->fullScreenRefreshRateComboBox->clear();
	ui->fullScreenRefreshRateComboBox->insertItems(0, fullscreenRatesList);
	ui->fullScreenRefreshRateComboBox->setCurrentIndex(fullscreenRate);
}

void ConfigDialog::on_texPackPathButton_clicked()
{
	QFileDialog::Options options = QFileDialog::DontResolveSymlinks | QFileDialog::ShowDirsOnly | QFileDialog::ReadOnly | QFileDialog::DontUseSheet | QFileDialog::ReadOnly | QFileDialog::HideNameFilterDetails;
	QString directory = QFileDialog::getExistingDirectory(this,
		"",
		ui->txPathLabel->text(),
		options);
	if (!directory.isEmpty())
		ui->txPathLabel->setText(directory);
}


void ConfigDialog::on_texCachePathButton_clicked()
{
	QFileDialog::Options options = QFileDialog::DontResolveSymlinks | QFileDialog::ShowDirsOnly | QFileDialog::ReadOnly | QFileDialog::DontUseSheet | QFileDialog::ReadOnly | QFileDialog::HideNameFilterDetails;
	QString directory = QFileDialog::getExistingDirectory(this,
		"",
		ui->txCachePathLabel->text(),
		options);
	if (!directory.isEmpty())
		ui->txCachePathLabel->setText(directory);
}

void ConfigDialog::on_texDumpPathButton_clicked()
{
	QFileDialog::Options options = QFileDialog::DontResolveSymlinks | QFileDialog::ShowDirsOnly | QFileDialog::ReadOnly | QFileDialog::DontUseSheet | QFileDialog::ReadOnly | QFileDialog::HideNameFilterDetails;
	QString directory = QFileDialog::getExistingDirectory(this,
		"",
		ui->txDumpPathLabel->text(),
		options);
	if (!directory.isEmpty())
		ui->txDumpPathLabel->setText(directory);
}

void ConfigDialog::on_windowedResolutionComboBox_currentIndexChanged(int index)
{
	if (index < numWindowedModes)
		ui->windowedResolutionComboBox->clearFocus();
}

void ConfigDialog::on_windowedResolutionComboBox_currentTextChanged(QString text)
{
	if (text == tr("Custom"))
		ui->windowedResolutionComboBox->setCurrentText("");
}

void ConfigDialog::on_cropImageComboBox_currentIndexChanged(int index)
{
	const bool bCustom = index == Config::cmCustom;
	ui->cropImageCustomFrame->setVisible(bCustom);
}

void ConfigDialog::on_frameBufferCheckBox_toggled(bool checked)
{

	if (!checked) {
		ui->nativeRes2DFrame->setEnabled(true);
	}  else {
		ui->nativeRes2DFrame->setEnabled(!ui->factor1xRadioButton->isChecked());
	}

	ui->readColorChunkCheckBox->setEnabled(checked && ui->fbInfoEnableCheckBox->isChecked());
	ui->readDepthChunkCheckBox->setEnabled(checked && ui->fbInfoEnableCheckBox->isChecked());
}

void ConfigDialog::on_fontTreeWidget_currentItemChanged(QTreeWidgetItem *current, QTreeWidgetItem * /*previous*/)
{
	if (current->childCount() > 0) {
		ui->fontLineEdit->setText(current->child(0)->text(0));
		m_font.setFamily(current->text(0));
	} else {
		ui->fontLineEdit->setText(current->text(0));
		m_font.setFamily(current->parent()->text(0));
	}
	ui->fontPreviewLabel->setFont(m_font);
}

void ConfigDialog::on_fontSizeSpinBox_valueChanged(int value)
{
	m_font.setPixelSize(value);
	ui->fontPreviewLabel->setFont(m_font);
}

void ConfigDialog::on_tabWidget_currentChanged(int tab)
{
	if (!m_fontsInited && ui->tabWidget->tabText(tab) == tr("OSD")) {
		ui->tabWidget->setCursor(QCursor(Qt::WaitCursor));

		QMap<QString, QStringList> internalFontList;
		QDir fontDir(QStandardPaths::locate(QStandardPaths::FontsLocation, QString(), QStandardPaths::LocateDirectory));
		QStringList fontFilter;
		fontFilter << "*.ttf";
		fontDir.setNameFilters(fontFilter);
		QFileInfoList fontList = fontDir.entryInfoList();
		for (int i = 0; i < fontList.size(); ++i) {
			int id = QFontDatabase::addApplicationFont(fontList.at(i).absoluteFilePath());
			QString fontListFamily = QFontDatabase::applicationFontFamilies(id).at(0);
			internalFontList[fontListFamily].append(fontList.at(i).fileName());
		}

		QMap<QString, QStringList>::const_iterator i;
		for (i = internalFontList.constBegin(); i != internalFontList.constEnd(); ++i) {
			QTreeWidgetItem *fontFamily = new QTreeWidgetItem(ui->fontTreeWidget);
			fontFamily->setText(0, i.key());
			for (int j = 0; j < i.value().size(); ++j) {
				QTreeWidgetItem *fontFile = new QTreeWidgetItem(fontFamily);
				fontFile->setText(0, i.value()[j]);
				if (i.value()[j] == ui->fontLineEdit->text()) {
					fontFamily->setExpanded(true);
					fontFile->setSelected(true);
					ui->fontTreeWidget->scrollToItem(fontFile);
					m_font.setFamily(i.key());
					ui->fontPreviewLabel->setFont(m_font);
				}
			}
		}

		ui->tabWidget->setCursor(QCursor(Qt::ArrowCursor));
		m_fontsInited = true;
	}
}
