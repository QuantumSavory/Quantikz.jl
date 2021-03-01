using Quantikz, Test

function stringtests()
@testset "String conversions" begin
circuit = [
           CNOT(1,2),CPHASE(2,3),
           CPHASE(4,5),
           CNOT(4,2),
           CPHASE(5,3),
           SWAP(1,2),
           Measurement(1),Measurement("A",2),
           H(3),P(4),U("G",5)
           ]
@test circuit2string(circuit) == "\\begin{quantikz}[transparent]\n\\qw & \\ctrl{0} & \\qw & \\qw & \\swap{0} & \\meterD{} & \\\\\n\\qw & \\targ{}\\vqw{-1} & \\ctrl{0} & \\targ{}\\vqw{0} & \\swap{-1} & \\meterD{A} & \\\\\n\\qw & \\qw & \\ctrl{-1} & \\qw & \\ctrl{0} & \\gate{H} & \\qw\\\\\n\\qw & \\ctrl{0} & \\qw & \\ctrl{-2} & \\qw & \\gate{P} & \\qw\\\\\n\\qw & \\ctrl{-1} & \\qw & \\qw & \\ctrl{-2} & \\gate{G} & \\qw\n\\end{quantikz}"
@test circuit2string(circuit, mode=:expanded) == "\\begin{quantikz}[transparent]\n\\qw & \\ctrl{0} & \\qw & \\qw & \\qw & \\qw & \\swap{0} & \\meterD{} &  &  &  &  & \\\\\n\\qw & \\targ{}\\vqw{-1} & \\ctrl{0} & \\qw & \\targ{}\\vqw{0} & \\qw & \\swap{-1} & \\qw & \\meterD{A} &  &  &  & \\\\\n\\qw & \\qw & \\ctrl{-1} & \\qw & \\qw & \\ctrl{0} & \\qw & \\qw & \\qw & \\gate{H} & \\qw & \\qw & \\qw\\\\\n\\qw & \\qw & \\qw & \\ctrl{0} & \\ctrl{-2} & \\qw & \\qw & \\qw & \\qw & \\qw & \\gate{P} & \\qw & \\qw\\\\\n\\qw & \\qw & \\qw & \\ctrl{-1} & \\qw & \\ctrl{-2} & \\qw & \\qw & \\qw & \\qw & \\qw & \\gate{G} & \\qw\n\\end{quantikz}"

circuit = [MultiControl([1,7],[3],[2,10],[9,12])]
@test circuit2string(circuit) == "\\begin{quantikz}[transparent]\n\\qw & \\ctrl{0} & \\qw\\\\\n\\qw & \\targ{}\\vqw{-1} & \\qw\\\\\n\\qw & \\octrl{-1} & \\qw\\\\\n\\qw & \\qw & \\qw\\\\\n\\qw & \\qw & \\qw\\\\\n\\qw & \\qw & \\qw\\\\\n\\qw & \\ctrl{-4} & \\qw\\\\\n\\qw & \\qw & \\qw\\\\\n\\qw & \\swap{-2} & \\qw\\\\\n\\qw & \\targ{}\\vqw{-1} & \\qw\\\\\n\\qw & \\qw & \\qw\\\\\n\\qw & \\swap{-2} & \\qw\n\\end{quantikz}"

circuit = [
    MultiControlU("U",[1,2],[3,8],[5,7]),
    MultiControlU("U_a",[1,2],[],[4,5]),
    MultiControlU("U_b",[7,8],[],[1,2,3]),
    MultiControlU("U_c",[],[],[4,6])
]
@test circuit2string(circuit) == "\\begin{quantikz}[transparent]\n\\qw & \\ctrl{0} & \\ctrl{0} & \\gate[3]{U_b} & \\qw & \\qw\\\\\n\\qw & \\ctrl{-1} & \\ctrl{-1} &  & \\qw & \\qw\\\\\n\\qw & \\octrl{-1} & \\qw &  & \\qw & \\qw\\\\\n\\qw & \\qw & \\gate[2]{U_a}\\vqw{-2} & \\qw & \\gate[3,label style={yshift=0.2cm}]{U_c} & \\qw\\\\\n\\qw & \\gate[3,label style={yshift=0.2cm}]{U}\\vqw{-2} &  & \\qw & \\linethrough & \\qw\\\\\n\\qw & \\linethrough & \\qw & \\qw &  & \\qw\\\\\n\\qw &  & \\qw & \\ctrl{-4} & \\qw & \\qw\\\\\n\\qw & \\octrl{-1} & \\qw & \\ctrl{-5} & \\qw & \\qw\n\\end{quantikz}"

circuit = [
    Noise([1,5]),
    P(1),
    NoiseAll(),
    MultiControlU("U",[2],[],[3,4]),
    Noise([2,4]),
]
@test circuit2string(circuit) == "\\begin{quantikz}[transparent]\n\\qw & \\gate[1,style={starburst,starburst points=7,inner xsep=-2pt,inner ysep=-2pt,scale=0.5}]{} & \\gate{P} & \\gate[1,style={starburst,starburst points=7,inner xsep=-2pt,inner ysep=-2pt,scale=0.5}]{} & \\qw & \\qw & \\qw\\\\\n\\qw & \\qw & \\qw & \\gate[1,style={starburst,starburst points=7,inner xsep=-2pt,inner ysep=-2pt,scale=0.5}]{} & \\ctrl{0} & \\gate[1,style={starburst,starburst points=7,inner xsep=-2pt,inner ysep=-2pt,scale=0.5}]{} & \\qw\\\\\n\\qw & \\qw & \\qw & \\gate[1,style={starburst,starburst points=7,inner xsep=-2pt,inner ysep=-2pt,scale=0.5}]{} & \\gate[2]{U}\\vqw{-1} & \\qw & \\qw\\\\\n\\qw & \\qw & \\qw & \\gate[1,style={starburst,starburst points=7,inner xsep=-2pt,inner ysep=-2pt,scale=0.5}]{} &  & \\gate[1,style={starburst,starburst points=7,inner xsep=-2pt,inner ysep=-2pt,scale=0.5}]{} & \\qw\\\\\n\\qw & \\gate[1,style={starburst,starburst points=7,inner xsep=-2pt,inner ysep=-2pt,scale=0.5}]{} & \\qw & \\gate[1,style={starburst,starburst points=7,inner xsep=-2pt,inner ysep=-2pt,scale=0.5}]{} & \\qw & \\qw & \\qw\n\\end{quantikz}"
end
end

function pdftests()
@testset "Tectonic tests" begin
    c1 = [
        CNOT(2,1),
        CPHASE(2,3),
        H(4),P(5),
        SWAP(5,6),
        U("Gate",6),
        Measurement(1),
        Measurement("X",2)
    ]
    c2 = [
        MultiControlU("U",[1,2],[3,8],[5,7]),
        MultiControlU("U_a",[1,2],[],[4,5]),
        MultiControlU("U_b",[7,8],[],[1,2,3]),
        MultiControlU("U_c",[],[],[4,6])
    ]
    c3 = [
        Noise([1,5]),
        P(1),
        NoiseAll(),
        MultiControlU("U",[2],[],[3,4]),
        Noise([2,4]),
    ]
    @test savepdf(c1,"c1.pdf") == "c1.pdf" # just check that it runs at all
    @test savepdf(c2,"c2.pdf") == "c2.pdf" # just check that it runs at all
    @test savepdf(c3,"c3.pdf") == "c3.pdf" # just check that it runs at all
    rm("c1.pdf")
    rm("c2.pdf")
    rm("c3.pdf")
end
end

stringtests()
pdftests()