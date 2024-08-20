#include "AboutDialog.h"
#include "ui_AboutDialog.h"
#include <QPushButton>
#include <QDialogButtonBox>

AboutDialog::AboutDialog(QWidget *parent, Qt::WindowFlags f) :
	QDialog(parent, f),
	ui(new Ui::AboutDialog)
{
	ui->setupUi(this);
}

AboutDialog::~AboutDialog()
{
	delete ui;
}

void AboutDialog::_init()
{
	ui->buttonBox->button(QDialogButtonBox::Close)->setText(tr("Close"));
}
