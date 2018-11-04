using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Windows.Forms;
using GraphSharp.Sample;
using System.Windows.Forms.DataVisualization.Charting;
using System.IO;

namespace WinFormsGraphSharp
{
    public partial class MainForm : Form
    {

        public GraphSharpControl GraphControl { get; set; }

        public class libr
        {
            public static int CompareLower(libr a, libr b)
            {
                // Return result of CompareTo with lengths of both strings.
                return a.lower.CompareTo(b.lower);
            }

            public string name;
            public uint lower;
            public uint upper;

            public Dictionary<uint, uint> hits_map = new Dictionary<uint, uint>();

            public void add_hit(uint addr)
            {
                hits++;
                if (hits_map.ContainsKey(addr))
                    hits_map[addr]++;
                else
                    hits_map[addr] = 1;
            }

            public int hits;
            public int hits_inclusive
            {
                get
                {
                    return hits + sym.Sum(p => p.hits_inclusive);
                }
            }
            public uint offset;

            public bool contains(uint addr)
            {
                return addr>=lower && addr<upper;
            }

            public override string ToString()
            {
                return lower + "-" + upper + " " + name ;
            }

            public liblist sym = new liblist();

            public liblist flatten(liblist list = null)
            {
                if (list == null) list = new liblist();
                if (hits != 0)
                    list.Add(this);

                sym.Where(p => contains(p.lower+lower-offset)).ToList().ForEach(p => p.flatten(list));

                return list;
            }

            public void clear()
            {
                hits=0;
                sym.ForEach(p => p.clear());
            }

            public KeyValuePair<libr,uint> drill(uint addr)
            {
                uint obj_addr = addr - lower + offset;
                var better = sym.find(obj_addr);
                if (better != null)
                    return better.drill(obj_addr);
                else
                    return new KeyValuePair<libr,uint>(this,obj_addr);
            }

            public void Add(libr subsym)
            {
                sym.Add(subsym);
            }

            public libr find(string symname)
            {
                if (name == symname) return this;
                libr rv = null;

                foreach( var p in sym)
                    if ( (rv = p.find(symname)) != null)
                        break;

                return rv;
            }
        }

        public class liblist : List<libr>
        {
            public libr find(uint addr)
            {
                return this.Find(x => x.contains(addr));
            }

            public libr find(string name)
            {
                return this.Find(x => x.name == name);
            }

            public libr extend(string name, uint low, uint hi)
            {
                libr v = find(name);

                if (v == null)
                {
                    v = new libr();
                    v.name = name; v.lower = low; v.upper = hi;
                    Add(v);
                }

                v.lower = Math.Min(v.lower, low);
                v.upper= Math.Max(v.upper, hi);

                return v;
            }
        }

        libr space = new libr();
        //liblist sym = new liblist();
        List<KeyValuePair<string, string>> namemaps = new List<KeyValuePair<string, string>>();

        string symname(libr raw)
        {
            var s = namemaps.Find(x => x.Key == raw.name).Value;

            if (s != null && s != raw.name)
                return s + " (" + raw.name + ")";
            else
                return raw.name + "(" + raw.lower + ")" ;
        }

        public static List<uint>[] samples = new List<uint>[] { new List<uint>(), new List<uint>() };

        void parse_samples(string[] txt)
        {
            prof_hz = 1000000 / double.Parse(txt[0].Split(':')[1].Trim());

            for (int i=1; i < txt.Length; i++)
            {
                string l = txt[i];
                if (l.Length == 0)
                    continue;

                var o = l.Split(' ');

                for (int j = 0; j < 2; j++)
                {
                    uint addr = Convert.ToUInt32(o[j], 16);
                    samples[j].Add(addr);
                }
            }
        }

        void parse_vaddr(string[] txt)
        {
            for (int i = 1; i < txt.Length; i++)
            {
                string l = txt[i];

                string[] o = l.Split(new char[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
                libr lbr = new libr();
                if (o.Length >= 6)
                {
                    var range = o[0].Split('-');
                    lbr.name = o[5];

                    /*
                    if (lbr.name.EndsWith(".so"))
                        lbr.name = "lib://" + lbr.name.Split('/').Last();
                    */

                    lbr.lower = Convert.ToUInt32(range[0], 16);
                    lbr.upper = Convert.ToUInt32(range[1], 16);
                    if (o[2].Length < 10)
                        lbr.offset = Convert.ToUInt32(o[2], 16);

                    var lalias = space.find(lbr.name);

                    if (lalias != null)
                        lbr.sym = lalias.sym;

                    space.Add(lbr);
                }
            }
        }

        void parsesym_lib(string[] txt)
        {
            string name = txt[0].Split(':')[1].Trim();

            var liby = space.sym.Find(p => p.name.EndsWith(name));

            if (liby == null)
                return;

            for (int i = 1; i < txt.Length; i++)
            {
                string l = txt[i];

                string[] o = l.Split(new char[] { ' ' }, 3, StringSplitOptions.RemoveEmptyEntries);
                libr lbr = new libr();

                if (o.Length == 3)
                {
                    lbr.name = o[2];


                    lbr.lower = Convert.ToUInt32(o[0], 16);
                    lbr.upper = lbr.lower + Convert.ToUInt32(o[1], 10);
                    var aex = liby.sym.find(lbr.lower);

                    if (aex == null)
                        liby.sym.Add(lbr);
                }
            }

            liby.sym.Sort(libr.CompareLower);

            for (int i = 1; i < (liby.sym.Count - 1); i++)
            {
                if (liby.sym[i].upper == liby.sym[i].lower)
                    liby.sym[i].upper = liby.sym[i + 1].lower;
            }
        }

        private void parsesym_jit(string[] txt)
        {
            string name = txt[0].Split(':')[1].Trim();

            for (int i = 1; i < txt.Length; i++)
            {
                string l = txt[i];

                string[] o = l.Split(new char[] { ' ' }, 3, StringSplitOptions.RemoveEmptyEntries);
                libr lbr = new libr();

                if (o.Length == 3)
                {
                    lbr.name = name + "_" + o[2];


                    lbr.lower = Convert.ToUInt32(o[0], 16);
                    lbr.upper = lbr.lower + Convert.ToUInt32(o[1], 10);
                    var aex = space.drill(lbr.lower).Key;

                    if (aex != null)
                    {
                        var sm = space.sym.find(lbr.lower);
                        if (sm != aex)
                        {
                            lbr.lower -= sm.lower - sm.offset;
                            lbr.upper -= sm.lower - sm.offset;
                        }
                        lbr.lower -= aex.lower - aex.offset;
                        lbr.upper -= aex.lower - aex.offset;
                        aex.sym.Add(lbr);
                    }
                        
                }
            }

            //liby.sym.Sort(libr.CompareLower);

            /*

            for (int i = 1; i < (liby.sym.Count - 1); i++)
            {
                if (liby.sym[i].upper == liby.sym[i].lower)
                    liby.sym[i].upper = liby.sym[i + 1].lower;
            }
            */
        }

        public void parsesym_map(string[] txt)
        {

            var sym = space.sym.Find(p => p.name.EndsWith("libnullDC_Core.so")).sym;

            //override any other defined symbols (eg, dynlib)
            sym.Clear();

            int i = 1;

            for (; i < txt.Length; i++)
            {
                var l = txt[i];

                if (l.StartsWith(".text"))
                    break;
            }

            List<string> uln = new List<string>();

            for (i++; i < txt.Length; i++)
            {
                var l = txt[i];

                if (l.StartsWith(" .text") || l.StartsWith("     "))
                    uln.Add(l);
                else if (l.StartsWith(" *"))
                    continue;
                else
                    break;
            }


            libr csym = null;

            List<libr> sort_addr = new List<libr>();

            for (i = 0; i < uln.Count; i++)
            {
                var l = uln[i];

                if (l == "==xx==xx==")
                    break;
                else
                {
                    var o = l.Trim().Split(new char[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);

                    if (l.StartsWith(" .text."))
                    {
                        csym = new libr();

                        csym.name = o[0].Substring(6);

                        if ((/*csym.name[0] != '_' &&*/ o.Length >= 4) ||
                            (o.Length == 4 && l.EndsWith(".o"))
                           )
                        {
                            csym.lower = Convert.ToUInt32(o[1], 16);
                            csym.upper = csym.lower + Convert.ToUInt32(o[2], 16);
                        }

                        if (sym.find(csym.lower) == null)
                            sym.Add(csym);
                    }
                    else if (l.StartsWith(" .text   ") && Convert.ToUInt32(o[2], 16) > 0)
                    {
                        csym = new libr();
                        csym.name = "<unnamed>";
                        csym.lower = Convert.ToUInt32(o[1], 16);
                        csym.upper = csym.lower + Convert.ToUInt32(o[2], 16);

                        if (sym.find(csym.lower) != null)
                            sym.Add(csym);
                    }
                    else if (l.StartsWith("     "))
                    {
                        if (csym != null)
                        {
                            if (csym.lower == 0)
                            {
                                csym.lower = Convert.ToUInt32(o[0], 16);
                                csym.upper = csym.lower + Convert.ToUInt32(o[1], 16);
                            }
                            else
                            {
                                var s = l.Trim().Split(new char[] { ' ' }, 2)[1].Trim();
                                var a = Convert.ToUInt32(l.Trim().Split(new char[] { ' ' }, 2)[0].Trim(), 16);

                                if (csym.name == "<unnamed>")
                                    if (csym.lower == a)
                                        csym.name = s;
                                    else
                                        csym.name = "<unnamed> around " + s;

                                /*
                                if (csym.lower == a && csym.sym.Count == 0)
                                    namemaps.Add(new KeyValuePair<string, string>(csym.name, s));
                                else*/
                                {
                                    var xsym = new libr();
                                    xsym.name = s;
                                    xsym.lower = a;
                                    xsym.upper = csym.upper;
                                    csym.Add(xsym);

                                    if (!sort_addr.Contains(csym))
                                        sort_addr.Add(csym);
                                }
                            }
                        }
                    }
                }
            }

            foreach (var s in sort_addr)
            {
                if (s.sym.Count == 1 && s.lower == s.sym[0].lower)
                {
                    namemaps.Add(new KeyValuePair<string, string>(s.name, s.sym[0].name));
                    s.sym.Clear();
                }
                else
                {
                    var al = s.sym.OrderBy(p => p.lower).ToList();

                    al[0].lower = al[0].lower - s.lower;
                    //al[0].upper = s.upper;

                    for (int k = 1; k < al.Count(); k++)
                    {
                        al[k - 1].upper = al[k].lower - s.lower;
                        al[k].lower = al[k - 1].upper;
                        al[k].upper = s.upper - s.lower;
                    }
                }
            }
        }


        void reprof_load(string file)
        {
            space = new libr();

            space.name = "[Unknown addresses]";
            space.lower = 0x00000000;
            space.upper = 0xFFFFFFFF;

            string[] sections = File.ReadAllText(file).Split(new string[] { "==xx==xx==\n" }, StringSplitOptions.RemoveEmptyEntries);

            foreach (string sect in sections)
            {
                string[] txt = sect.Split('\n');

                string type = txt[0].Split(':')[0];

                switch (type)
                {
                    case "vaddr":
                        parse_vaddr(txt);
                        break;

                    case ".map":
                        if (checkBox2.Checked)
                            parsesym_map(txt);
                        break;

                    case "libsym":
                        if (checkBox3.Checked)
                            parsesym_lib(txt);
                        break;

                    case "jitsym":
                        if (checkBox1.Checked)
                            parsesym_jit(txt);
                        break;

                    case "samples":
                        parse_samples(txt);
                        break;
                }
            }
        }

        int reprof_analyse(int cntr, int sp=0, int ep=-1)
        {

            space.clear();

            var slist = samples[cntr];

            if (ep == -1 || ep > slist.Count)
                ep = slist.Count;

            if (sp > ep)
                sp = ep - 1;


            int count = ep - sp;

            for (int i=sp; i < ep; i++)
            {
                uint addr = slist[i];
                var d = space.drill(addr);
                d.Key.add_hit(d.Value);
            }

            return count;
        }

        class sample_point
        {
            public libr l;
            public double percent;
            public int hits;

            public sample_point(libr l, int cnt) { this.l = l; percent = l.hits * 100.0 / cnt; hits = l.hits; }
            public override string ToString()
            {
                return String.Format("{1:00.00}% | {0}", l.name, percent);
            }
        }

        double prof_hz = 3000;

        void reprof(int stp=0, int ep=-1)
        {
            if (stp == -2)
                stp = (int)(((double)numericUpDown2.Value) * prof_hz);

            if (ep == -2)
                ep = (int)(((double)numericUpDown3.Value) * prof_hz);

            StringBuilder sb = new StringBuilder();

            sb.AppendLine("\n");
            sb.AppendLine("******************-> " + reprof_filename + " <-******************");
            sb.AppendLine("\n");

            int cnt;
            cnt=reprof_analyse(0,stp,ep);

            //var top0 = lst.Concat(sym).OrderByDescending(x => x.hits).Where(x => x.hits != 0).Select(x => new sample_point(x,cnt)).ToArray();
            var topsym0 = space.flatten().OrderByDescending(x => x.hits).Where(x => x.hits != 0).Select(x => new sample_point(x, cnt)).ToArray();

            cnt = reprof_analyse(1,stp,ep);

            //var top1 = lst.OrderByDescending(x => x.hits).Where(x => x.hits != 0).Select(x => new sample_point(x, cnt)).ToArray();
            var topsym1 = space.flatten().OrderByDescending(x => x.hits).Where(x => x.hits != 0).Select(x => new sample_point(x, cnt)).ToArray();

            ep = stp + cnt;

            comboBox1.Items.Clear();
            foreach (var s in topsym0)
                comboBox1.Items.Add(s);
            
            comboBox1.SelectedIndex = 0;


            /*
            sb.AppendLine("Sh4 Thread");
            foreach (var x in top0)
                sb.AppendLine(String.Format("{1:0.00} {0}", x.l.name, x.percent));

            sb.AppendLine("\n\n\n");

            sb.AppendLine("Renderer Thread");

            foreach (var x in top1)
                sb.AppendLine(String.Format("{1:0.00} {0}", x.l.name, x.percent));


            sb.AppendLine("\n\n\n");
            */
            double csm;

            sb.AppendLine("Sh4 Thread SYMS");

            List<sample_point>[] sp = new List<sample_point>[] { new List<sample_point>(), new List<sample_point>() };

            csm = 0;
            foreach (var x in topsym0)
            {
                if (csm >= 98.5 || x.percent < 0.1) break;
                csm += x.percent;
                if (sp[0].Count<30)
                    sp[0].Add(x);

                sb.AppendLine(String.Format("{1:0.00} {0}", symname(x.l), x.percent));
            }

            sb.AppendLine(String.Format("{1:0.00} {0}", "Others", 100 - csm));


            sb.AppendLine("\n\n\n");

            sb.AppendLine("REND Thread SYMS");

            csm = 0;
            foreach (var x in topsym1)
            {
                if (csm >= 99.9 || x.percent < 0.1) break;
                csm += x.percent;

                if (sp[1].Count < 18)
                    sp[1].Add(x);

                sb.AppendLine(String.Format("{1:0.00} {0}", symname(x.l), x.percent));
            }

            sb.AppendLine(String.Format("{1:0.00} {0}", "Others", 100 - csm));

            richTextBox1.Text += sb.ToString();


            var ser = new Dictionary<libr,Series>();
            
            chart3.SuspendLayout();

            chart3.Series.Clear();
            chart3.Titles.Clear();

            chart3.Titles.Add(reprof_filename);
            chart3.Legends[0].MaximumAutoSize = 20;

            ser[space] = chart3.Series.Add("others");

            const int smpl_idx = 0;

            foreach (var s in sp[smpl_idx])
            {
                ser[s.l]=chart3.Series.Add(symname(s.l));
            }

            foreach (var z in ser.Values)
            {
                z.ToolTip = "#SERIESNAME: #VALY{#0.00}% (#VALX{#0.00}s)";
                z.ChartType = SeriesChartType.StackedArea;
            }

            
            int step_size = (int)numericUpDown1.Value;

            for (int i = stp; i < ep; i += step_size)
            {
                cnt=reprof_analyse(smpl_idx, i, i + step_size);
                topsym0 = space.flatten().OrderByDescending(x => x.hits).Where(x => x.hits != 0).Select(x => new sample_point(x, cnt)).ToArray();

                double s=0;
                double o = 0;
                foreach (var ts in topsym0)
                {
                    s += ts.percent;
                    if (ser.ContainsKey(ts.l))
                        ser[ts.l].Points.AddXY(i / prof_hz, ts.percent);
                    else
                        o += ts.percent;
                }

                if (Math.Abs(s-100) > 0.5)
                    throw new Exception("Graph Error!");
                ser[space].Points.AddXY(i / prof_hz, o + (100 - s));

                foreach (var z in ser.Values)
                {
                    if (ser[space].Points.Count != z.Points.Count)
                        z.Points.AddXY(i / prof_hz, 0);
                }
            }

            chart3.ResumeLayout(true);
        }

        string reprof_filename;
        public MainForm()
        {
            InitializeComponent();

            GraphControl = new GraphSharpControl(this);

            elementHost1.Child = GraphControl;

            reprof_filename = "c:\\SCintro.reprof";

            using (var dialog = new OpenFileDialog { Title = "Open reprof file", Filter = "reprof traces|*.reprof|All files|*.*" })
            {
                if (dialog.ShowDialog() == System.Windows.Forms.DialogResult.OK)
                {
                    reprof_filename = dialog.FileName;
                }
            }

            reprof_load(reprof_filename);

            reprof();
        }

        private void helpToolStripButton_Click(object sender, EventArgs e)
        {
            
        }

        private void OpenFile(string fileName)
        {
            GraphControl.OpenFile(fileName);
        }

        private void OpenFile()
        {
            using (var dialog = new OpenFileDialog {Title = "Open GML file", Filter = "GML files|*.gml|All files|*.*"})
            {
                if (dialog.ShowDialog() == System.Windows.Forms.DialogResult.OK)
                {
                    OpenFile(dialog.FileName);
                }
            }
        }
        private void openToolStripButton_Click(object sender, EventArgs e)
        {
            OpenFile();
        }

        private void NewGraph()
        {
            GraphControl = new GraphSharpControl(this);

            elementHost1.Child = GraphControl;
        }
        private void newToolStripButton_Click(object sender, EventArgs e)
        {
            NewGraph();
        }

        private void exitToolStripMenuItem_Click(object sender, EventArgs e)
        {
            Close();
        }

        private void toolStripContainer1_ContentPanel_Load(object sender, EventArgs e)
        {

        }

        private void chart1_DoubleClick(object sender, EventArgs e)
        {
            var chart = sender as Chart;

            //while (chart1.ChartAreas[0].AxisX.ScaleView.IsZoomed)
                chart.ChartAreas[0].AxisX.ScaleView.ZoomReset();

            //while (chart1.ChartAreas[0].AxisY.ScaleView.IsZoomed)
                chart.ChartAreas[0].AxisY.ScaleView.ZoomReset();
        }

        private void button3_Click(object sender, EventArgs e)
        {
            reprof(-2,-2);
        }

        private void numericUpDown1_ValueChanged(object sender, EventArgs e)
        {

        }

        private void button1_Click(object sender, EventArgs e)
        {
            using (var dialog = new SaveFileDialog { Title = "Save png file", Filter = "png files|*.png|All files|*.*" })
            {
                if (dialog.ShowDialog() == System.Windows.Forms.DialogResult.OK)
                {
                    chart3.SaveImage(dialog.FileName, ChartImageFormat.Png);
                }
            }

        }

        private void chart3_DoubleClick(object sender, EventArgs e)
        {
            //while (chart1.ChartAreas[0].AxisX.ScaleView.IsZoomed)
            chart3.ChartAreas[0].AxisX.ScaleView.ZoomReset();

            //while (chart1.ChartAreas[0].AxisY.ScaleView.IsZoomed)
            chart3.ChartAreas[0].AxisY.ScaleView.ZoomReset();
        }

       

        private void button2_Click(object sender, EventArgs e)
        {
            reprof(-2, -2);

            while (chart3.ChartAreas[0].AxisX.ScaleView.IsZoomed)
                chart1.ChartAreas[0].AxisX.ScaleView.ZoomReset();

            while (chart1.ChartAreas[0].AxisY.ScaleView.IsZoomed)
                chart1.ChartAreas[0].AxisY.ScaleView.ZoomReset();
        }



        private void numericUpDown1_KeyPress(object sender, KeyPressEventArgs e)
        {
            if (e.KeyChar == '\n')
                button3_Click(null, null);
        }
        private void numericUpDown_2_3_KeyPress(object sender, KeyPressEventArgs e)
        {
            if (e.KeyChar == '\n')
                button2_Click(null, null);
        }

        private void button4_Click(object sender, EventArgs e)
        {
            numericUpDown2.Value = (decimal)chart3.ChartAreas[0].AxisX.ScaleView.ViewMinimum;
            numericUpDown3.Value = (decimal)chart3.ChartAreas[0].AxisX.ScaleView.ViewMaximum;
        }

        private void tabPage4_Click(object sender, EventArgs e)
        {

        }

        private void button5_Click(object sender, EventArgs e)
        {
            richTextBox1.Text = "";
            reprof_load(reprof_filename);

            reprof();
        }

        private void button6_Click(object sender, EventArgs e)
        {
            var sp = comboBox1.SelectedItem as sample_point;


            StringBuilder sb = new StringBuilder();

            sb.AppendLine("Ordered by Addr");

            foreach (var p in sp.l.hits_map.OrderBy(x => x.Key))
            {
                sb.AppendLine(Convert.ToString(p.Key, 10).PadLeft(8) + " " + p.Value);
            }

            sb.AppendLine("Ordered by Hits");

            foreach (var p in sp.l.hits_map.OrderByDescending(x => x.Value))
            {
                sb.AppendLine(Convert.ToString(p.Key, 10).PadLeft(8) + " " + p.Value);
            }

            richTextBox2.Text = sb.ToString();
        }
    }
}
