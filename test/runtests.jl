using Quantikz, Test

circuit = [
           CNOT(1,2),CPHASE(2,3),
           CPHASE(4,5),
           CNOT(4,2),
           CPHASE(5,3),
           SWAP(1,2),
           Measurement(1),Measurement("A",2),
           H(3),P(4),U("G",5)
           ]
@test circuit2string(circuit) == "\\begin{quantikz}\n\\qw & \\ctrl{0} & \\qw & \\qw & \\swap{0} & \\meterD{} & \\\\\n\\qw & \\targ{}\\vqw{-1} & \\ctrl{0} & \\targ{}\\vqw{0} & \\swap{-1} & \\meterD{A} & \\\\\n\\qw & \\qw & \\ctrl{-1} & \\qw & \\ctrl{0} & \\gate{H} & \\qw\\\\\n\\qw & \\ctrl{0} & \\qw & \\ctrl{-2} & \\qw & \\gate{P} & \\qw\\\\\n\\qw & \\ctrl{-1} & \\qw & \\qw & \\ctrl{-2} & \\gate{G} & \\qw\n\\end{quantikz}"
@test circuit2string(circuit, mode=:expanded) == "\\begin{quantikz}\n\\qw & \\ctrl{0} & \\qw & \\qw & \\qw & \\qw & \\swap{0} & \\meterD{} &  &  &  &  & \\\\\n\\qw & \\targ{}\\vqw{-1} & \\ctrl{0} & \\qw & \\targ{}\\vqw{0} & \\qw & \\swap{-1} & \\qw & \\meterD{A} &  &  &  & \\\\\n\\qw & \\qw & \\ctrl{-1} & \\qw & \\qw & \\ctrl{0} & \\qw & \\qw & \\qw & \\gate{H} & \\qw & \\qw & \\qw\\\\\n\\qw & \\qw & \\qw & \\ctrl{0} & \\ctrl{-2} & \\qw & \\qw & \\qw & \\qw & \\qw & \\gate{P} & \\qw & \\qw\\\\\n\\qw & \\qw & \\qw & \\ctrl{-1} & \\qw & \\ctrl{-2} & \\qw & \\qw & \\qw & \\qw & \\qw & \\gate{G} & \\qw\n\\end{quantikz}"

circuit = [MultiControl([1,7],[3],[2,10],[9,12])]
@test circuit2string(circuit) == "\\begin{quantikz}\n\\qw & \\ctrl{0} & \\qw\\\\\n\\qw & \\targ{}\\vqw{-1} & \\qw\\\\\n\\qw & \\octrl{-1} & \\qw\\\\\n\\qw & \\qw & \\qw\\\\\n\\qw & \\qw & \\qw\\\\\n\\qw & \\qw & \\qw\\\\\n\\qw & \\ctrl{-4} & \\qw\\\\\n\\qw & \\qw & \\qw\\\\\n\\qw & \\swap{-2} & \\qw\\\\\n\\qw & \\targ{}\\vqw{-1} & \\qw\\\\\n\\qw & \\qw & \\qw\\\\\n\\qw & \\swap{-2} & \\qw\n\\end{quantikz}"