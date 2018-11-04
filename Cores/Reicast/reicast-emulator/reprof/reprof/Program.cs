using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Windows.Forms;

namespace WinFormsGraphSharp
{
    class Program
    {
        public static MainForm frm;
        [STAThread]
        static void Main(string[] args)
        {
            frm = new MainForm();
            Application.Run(frm);
        }
    }
}
