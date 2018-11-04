using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Navigation;
using System.Windows.Shapes;
using System.Xml;
using GraphSharp.Sample;
using QuickGraph;
using GraphSharp;
using GraphSharp.Controls;
using QuickGraph.Serialization;
using System.IO;
using System.Dynamic;
using System.Reflection;
using System.Windows.Forms.DataVisualization.Charting;

namespace WinFormsGraphSharp
{
    public class CodeBlocky : DynamicObject
    {

        public CodeBlocky() 
        {
            _members.Add("block", 0U);
            _members.Add("addr", 0U);
            _members.Add("code", 0U);
            _members.Add("runs", 0U);
            _members.Add("BlockType", 0U);
            _members.Add("NextBlock", 0U);
            _members.Add("BranchBlock", 0U);
            _members.Add("pNextBlock", 0U);
            _members.Add("pBranchBlock", 0U);
            _members.Add("guest_cycles", 0U);
            _members.Add("guest_opcodes", 0U);
            _members.Add("host_opcodes", 0U);
            _members.Add("il_opcodes", 0U);

            _members.Add("dict", _members);
            _members.Add("obj", this);
        }

        private Dictionary < string, object > _members = new Dictionary < string, object > ();


        /// <summary>
        /// When a new property is set, add the property name and value to the dictionary
        /// </summary>     
        public override bool TrySetMember(SetMemberBinder binder, object value)
        {
            return TrySet(binder.Name, value);
        }

        bool TrySet(string n, object v)
        {
            if (v.GetType() == _members[n].GetType())
                _members[n] = v;
            else if (_members[n].GetType() == typeof(uint))
            {
                uint rv;

                if (!uint.TryParse(v.ToString(), out rv))
                    rv = Convert.ToUInt32(v.ToString(), 16);

                _members[n] = rv;
            }
            else
                return false;

            return true;
        }

        /// <summary>
        /// When user accesses something, return the value if we have it
        /// </summary>      
        public override bool TryGetMember(GetMemberBinder binder, out object result)
        {
            if (_members.ContainsKey(binder.Name))
            {
                result = _members[binder.Name];
                return true;
            }
            else
            {
                result = null;
                return false;
            }
        }

        /// <summary>
        /// If a property value is a delegate, invoke it
        /// </summary>     
        public override bool TryInvokeMember(InvokeMemberBinder binder, object[] args, out object result)
        {
            if (_members.ContainsKey(binder.Name) && _members[binder.Name] is Delegate)
            {
                result = (_members[binder.Name] as Delegate).DynamicInvoke(args);
                return true;
            }
            else
            {
                return base.TryInvokeMember(binder, args, out result);
            }
        }


        /// <summary>
        /// Return all dynamic member names
        /// </summary>
        /// <returns></returns>
        public override IEnumerable<string> GetDynamicMemberNames()
        {
            return _members.Keys;
        }

        public dynamic this[string v]
        {
            get { return _members[v]; }
            set { if (!TrySet(v,value)) throw new InvalidOperationException("Check your types!"); }
        }

        public dynamic dyn { get { return this; } }
    }

    public class FlexibleObj
    {
        bool TrySet(string n, object v)
        {
            FieldInfo f= this.GetType().GetField(n);

            Type t = f.FieldType;

            if (v.GetType() == t)
                f.SetValue(this, v);
            else if (t == typeof(uint))
            {
                uint rv;
                string s = v.ToString().Trim();

                if (!uint.TryParse(s, out rv))
                    rv = Convert.ToUInt32(s, 16);

                f.SetValue(this,rv);
            }
            else
                return false;

            return true;
        }


        public dynamic this[string v]
        {
            get 
            {
                return this.GetType().GetField(v.Trim()).GetValue(this);
            }
            set { if (!TrySet(v.Trim(), value)) throw new InvalidOperationException("Check your types!"); }
        }
    }

    public class CodeBlock : FlexibleObj
    {
        public static long gcost;

        public 
        uint block,addr,code,runs,BlockType,NextBlock,BranchBlock,pNextBlock,pBranchBlock,
             guest_cycles,guest_opcodes,host_opcodes,il_opcodes;
        public double cumsum;
        public string hash;

        public uint cost { get { return runs /* host_opcodes*/; } }
        public uint pos { get { return (addr & (16 * 1024 * 1024 - 1)) / 4; } }

        public override string ToString()
        {
            return Convert.ToString(block, 16) + " -> " + Convert.ToString(addr, 16) + ": " + String.Format("{0:0.00}", cost * 100.0 / gcost) + "%(r:" + runs + ", ops:" + guest_opcodes + ", c:" + guest_cycles + ")";
        }
    }

    /// <summary>
    /// Interaction logic for GraphSharpControl.xaml
    /// </summary>
    public partial class GraphSharpControl : UserControl
    {
        public GraphSharpControl(MainForm frm)
        {
            InitializeComponent();
        }

        void RecGraph(MainForm frm, string file)
        {

            var g = new CompoundGraph<object, IEdge<object>>();

            var map = new Dictionary<uint, CodeBlock>();

            string[] ent = File.ReadAllText(file).Split(new string[] { "block:" }, StringSplitOptions.RemoveEmptyEntries);

            foreach (string e in ent)
            {
                string[] st = e.Split(new string[] { "\r\n" }, StringSplitOptions.RemoveEmptyEntries);

                var entr = new CodeBlock();

                entr["block"] = st[0];

                for (int i = 1; i < st.Length; i++)
                {
                    if (st[i] == "{")
                        break;
                    else
                    {
                        string[] lst = st[i].Split(new char[] { ':' }, 2);
                        if (lst.Length == 2)
                        {
                            entr[lst[0]] = lst[1];
                        }
                    }
                }

                map[entr.block] = entr;
            }

            map = map.Where(x => x.Value.runs > 0).ToDictionary(x => x.Key, x => x.Value);

            long v = map.Sum(x => x.Value.cost);

            CodeBlock.gcost = v;

            double runcumsum = 0;

            var intrnode = map.Values.OrderByDescending(x => x.cost).Where(x => (runcumsum += x.cost) < 0.60 * v).Take(1000).ToList();

            var varp = intrnode.Select(x => x.hash);

            long v1 = intrnode.Sum(x => x.cost);

            foreach (var r in intrnode)
            {
                g.AddVertex(r);
            }

            var newstuff = new List<CodeBlock>();

        reloop:
            foreach (var r in intrnode)
            {
                CodeBlock va, vb;


                if (map.TryGetValue(r["pNextBlock"], out va))
                {
                    if (!g.ContainsVertex(va)) { newstuff.Add(va); g.AddVertex(va); v1 += va.cost; }

                    g.AddEdge(new Edge<object>(r, va));
                }

                if (map.TryGetValue(r["pBranchBlock"], out vb))
                {
                    if (!g.ContainsVertex(vb)) { newstuff.Add(vb); g.AddVertex(vb); v1 += vb.cost; }

                    g.AddEdge(new Edge<object>(r, vb));
                }
            }

            if (newstuff.Count != 0)
            {
                intrnode = newstuff;
                newstuff = new List<CodeBlock>();
                goto reloop;
            }

            frm.Text = "Showing " + v1 * 100 / v + "% (using " + g.VertexCount + " out of " + map.Count + ", " + g.VertexCount * 100 / map.Count + "% of blocks)";


            var ordlst = map.Values.OrderByDescending(x => x.cost).ToList();

            double rvv = 0;



            foreach (var i in ordlst)
            {
                rvv += i.cost;
                i.cumsum = rvv;
            }

            var cs = frm.chart2.Series.Add("CumSum(cost) / decrease(cost)");
            var pr = frm.chart1.Series.Add("Cost / addr");
            var bl = frm.chart1.Series.Add("gopc / addr");
            var gs = frm.chart1.Series.Add("cycl / addr");

            cs.ChartType = SeriesChartType.StepLine;

            pr.ChartType = SeriesChartType.BoxPlot;
            bl.ChartType = SeriesChartType.BoxPlot;
            gs.ChartType = SeriesChartType.BoxPlot;

            foreach (var i in ordlst)
            {
                cs.Points.AddY(i.cumsum * 100.0 / CodeBlock.gcost);
            }

            rvv = 0;
            foreach (var i in ordlst.OrderBy(x => x.pos))
            {
                rvv += i.cost;
                //if (rvv > v * 0.01)
                {
                    pr.Points.AddXY(i.pos, Math.Log(i.cost + 1));
                    bl.Points.AddXY(i.pos, Math.Log(i.guest_opcodes + 1));
                    gs.Points.AddXY(i.pos, Math.Log(i.guest_cycles / 4 + 1));
                }
            }
            /*
            var vertices = new string[30];
            
            for (int i = 0; i < 30; i++)
            {
                vertices[i] = i.ToString();
                g.AddVertex(vertices[i]);
            }
            
            for (int i = 6; i < 15; i++)
            {
                g.AddChildVertex(vertices[i % 5], vertices[i]);
            }
            g.AddChildVertex(vertices[5], vertices[4]);
            g.AddChildVertex(vertices[5], vertices[2]);
            g.AddChildVertex(vertices[16], vertices[0]);
            g.AddChildVertex(vertices[16], vertices[1]);
            g.AddChildVertex(vertices[16], vertices[3]);
            g.AddChildVertex(vertices[16], vertices[20]);
            g.AddChildVertex(vertices[16], vertices[21]);
            g.AddChildVertex(vertices[16], vertices[22]);
            g.AddChildVertex(vertices[16], vertices[23]);
            g.AddChildVertex(vertices[16], vertices[24]);
            g.AddChildVertex(vertices[4], vertices[25]);
            g.AddChildVertex(vertices[4], vertices[26]);
            g.AddChildVertex(vertices[4], vertices[27]);

            g.AddEdge(new Edge<object>(vertices[0], vertices[1]));
            g.AddEdge(new Edge<object>(vertices[0], vertices[2]));
            g.AddEdge(new Edge<object>(vertices[2], vertices[4]));
            g.AddEdge(new Edge<object>(vertices[0], vertices[7]));
            g.AddEdge(new Edge<object>(vertices[8], vertices[7]));
            //g.AddEdge(new Edge<object>(vertices[13], vertices[12]));
            g.AddEdge(new Edge<object>(vertices[3], vertices[20]));
            g.AddEdge(new Edge<object>(vertices[20], vertices[21]));
            g.AddEdge(new Edge<object>(vertices[20], vertices[22]));
            g.AddEdge(new Edge<object>(vertices[22], vertices[23]));
            g.AddEdge(new Edge<object>(vertices[23], vertices[24]));
            g.AddEdge(new Edge<object>(vertices[0], vertices[28]));
            g.AddEdge(new Edge<object>(vertices[0], vertices[29]));
            g.AddEdge(new Edge<object>(vertices[25], vertices[27]));
            g.AddEdge(new Edge<object>(vertices[26], vertices[25]));
            g.AddEdge(new Edge<object>(vertices[14], vertices[27]));
            g.AddEdge(new Edge<object>(vertices[14], vertices[26]));
            g.AddEdge(new Edge<object>(vertices[14], vertices[25]));
            g.AddEdge(new Edge<object>(vertices[26], vertices[27]));
            */

            layout.LayoutMode = LayoutMode.Automatic;
            layout.LayoutAlgorithmType = "CompoundFDP";
            layout.OverlapRemovalConstraint = AlgorithmConstraints.Automatic;
            layout.OverlapRemovalAlgorithmType = "FSA";
            layout.HighlightAlgorithmType = "Simple";

            /*
            using (FileStream w = File.Create("c:\\fail.bin"))
                g.SerializeToBinary(w);
            */

            layout.Graph = g;
        }
        public void OpenFile(string fileName)
        {
            //graph where the vertices and edges should be put in
            var graph = new CompoundGraph<object, IEdge<object>>();
        
            try
            {
                //open the file of the graph
                var reader = XmlReader.Create(fileName);

                //create the serializer
                var serializer = new GraphMLDeserializer<object, IEdge<object>, CompoundGraph<object, IEdge<object>>>();


                //deserialize the graph
                serializer.Deserialize(reader, graph,
                                       id => id, (source, target, id) => new Edge<object>(source, target)
                    );

            }
            catch (Exception ex)
            {
                Debug.WriteLine(ex);
            }
            layout.Graph = graph;
            layout.UpdateLayout();

        }

        private IBidirectionalGraph<object, IEdge<object>> ConvertGraph(PocGraph graph)
        {
            var g = new CompoundGraph<object, IEdge<object>>();

            foreach (var item in graph.Vertices)
            {
                g.AddVertex(item.ID);

            }

            foreach (var item in graph.Edges)
            {
                g.AddEdge(new Edge<object>(item.Source.ID, item.Target.ID));
            }


            return g;
        }

        private void Relayout_Click(object sender, RoutedEventArgs e)
        {
            layout.Relayout();
        }

    }
}
