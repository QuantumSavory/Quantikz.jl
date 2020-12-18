using Quantikz, Test

circuit = [
    CNOT(1,2),CPHASE(2,3),
    CNOT(2,4),
    CPHASE(5,3),
    Measurement(1),Measurement("A",2),
    H(3),P(4),U("G",5)
    ]

@test circuit2string(circuit) == "\\begin{quantikz}\n\\qw & \\ctrl{1} & \\qw & \\qw & \\qw & \\meterD{} &  &  &  &  & \\\\\n\\qw & \\targ{} & \\ctrl{1} & \\ctrl{2} & \\qw & \\qw & \\meterD{A} &  &  &  & \\\\\n\\qw & \\qw & \\control{} & \\qw & \\control{} & \\qw & \\qw & \\gate{H} & \\qw & \\qw & \\qw\\\\\n\\qw & \\qw & \\qw & \\targ{} & \\qw & \\qw & \\qw & \\qw & \\gate{P} & \\qw & \\qw\\\\\n\\qw & \\qw & \\qw & \\qw & \\ctrl{-2} & \\qw & \\qw & \\qw & \\qw & \\gate{G} & \\qw\n\\end{quantikz}"