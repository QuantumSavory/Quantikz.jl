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

@test circuit2string(circuit) == "\\begin{quantikz}\n\\qw & \\ctrl{1} & \\qw & \\qw & \\swap{1} & \\meterD{} & \\\\\n\\qw & \\targ{} & \\ctrl{1} & \\targ{} & \\targX{} & \\meterD{A} & \\\\\n\\qw & \\qw & \\control{} & \\qw & \\control{} & \\gate{H} & \\qw\\\\\n\\qw & \\ctrl{1} & \\qw & \\ctrl{-2} & \\qw & \\gate{P} & \\qw\\\\\n\\qw & \\control{} & \\qw & \\qw & \\ctrl{-2} & \\gate{G} & \\qw\n\\end{quantikz}"
@test circuit2string(circuit, mode=:expanded) == "\\begin{quantikz}\n\\qw & \\ctrl{1} & \\qw & \\qw & \\qw & \\qw & \\swap{1} & \\meterD{} &  &  &  &  & \\\\\n\\qw & \\targ{} & \\ctrl{1} & \\qw & \\targ{} & \\qw & \\targX{} & \\qw & \\meterD{A} &  &  &  & \\\\\n\\qw & \\qw & \\control{} & \\qw & \\qw & \\control{} & \\qw & \\qw & \\qw & \\gate{H} & \\qw & \\qw & \\qw\\\\\n\\qw & \\qw & \\qw & \\ctrl{1} & \\ctrl{-2} & \\qw & \\qw & \\qw & \\qw & \\qw & \\gate{P} & \\qw & \\qw\\\\\n\\qw & \\qw & \\qw & \\control{} & \\qw & \\ctrl{-2} & \\qw & \\qw & \\qw & \\qw & \\qw & \\gate{G} & \\qw\n\\end{quantikz}"