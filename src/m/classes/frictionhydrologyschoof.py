import numpy as np
from checkfield import checkfield
from fielddisplay import fielddisplay
from project3d import project3d
from structtoobj import structtoobj
from WriteData import WriteData


class frictionhydrologyschoof(object):
    """FRICTIONSCHOOFGLADS class definition

    Usage:
        friction = frictionschoofglads()
    """

    def __init__(self, *args):  # {{{
        self.C                        = np.nan
        self.zeta                     = np.nan
        self.m                        = np.nan
        self.lambd		      = 0
        self.coupling                 = 0
        self.effective_pressure       = np.nan
        self.sheet_thickness          = np.nan
        self.effective_pressure_limit = 0
        self.rheology_A       	      = np.nan
	self.bump_height              = np.nan
	self.bump_spacing             = np.nan

        nargs = len(args)
        if nargs == 0:
            self.setdefaultparameters()
        elif nargs == 1:
            self = structtoobj(self, args[0])
        else:
            raise Exception('constructor not supported')
    # }}}
    def __repr__(self):  # {{{
        s = 'Hydrology modified Schoof sliding law parameters:\n'
        s += '   Hydrology modified Schoof sliding law reads:\n'
        s += '                                      C^2 |u_b|^(m-1)                                                                        h_r\n'
	s += '      tau_b = - _____________________________________________________________ u_b, tildeh = lambda h + (1-lambda)  __________________________\n'
	s += '                 (1+(zeta^(1/m) A l_r tildeh/(h_r - tildeh)))^1/m |u_b| )^m                                         1 + A l_r u_b / N^(1/m)\n'
        s += '\n'
        s += "{}\n".format(fielddisplay(self, 'C', 'friction coefficient [SI]'))
        s += "{}\n".format(fielddisplay(self, 'zeta', 'degree that cavitation plays a role in the sliding regime'))
        s += "{}\n".format(fielddisplay(self, 'm', 'm exponent (generally taken as m = 1/n = 1/3)'))
        s += "{}\n".format(fielddisplay(self, 'lambd', 'parameter between 0 and 1 that controls the importance of the past state of the system (default 0 for complete effective pressure dependence)'))
        s += "{}\n".format(fielddisplay(self, 'rheology_A', 'ice flow parameter [Pa^3 s^(-1)]'))
        s += "{}\n".format(fielddisplay(self, 'bump_height', 'bedrock bump height [m]'))
        s += "{}\n".format(fielddisplay(self, 'bump_spacing', 'bedrock bump spacing [m]'))
        s += '{}\n'.format(fielddisplay(self, 'effective_pressure', 'Effective Pressure for the forcing if not coupled [Pa]'))
        s += '{}\n'.format(fielddisplay(self, 'sheet_thickness', 'hydrology sheet thickness for the forcing if not coupled [m]'))
        s += '{}\n'.format(fielddisplay(self, 'coupling', 'Coupling flag 0: uniform sheet (negative pressure ok, default), 1: ice pressure only, 2: water pressure assuming uniform sheet (no negative pressure), 3: use provided effective_pressure, 4: used coupled model (not implemented yet)'))
        s += "{}\n".format(fielddisplay(self, 'effective_pressure_limit', 'fNeff do not allow to fall below a certain limit: effective_pressure_limit*rho_ice*g*thickness (default 0)'))
        return s
    # }}}
    def setdefaultparameters(self):  # {{{
        self.coupling = 0
        self.effective_pressure_limit = 0
        self.lambd = 0.
	self.zeta = 1e7
        return self
    # }}}
    def extrude(self, md):  # {{{
        self.C = project3d(md, 'vector', self.C, 'type', 'node')
        self.zeta = project3d(md, 'vector', self.zeta, 'type', 'node')
        self.m = project3d(md, 'vector', self.m, 'type', 'element')
        if self.coupling in [3, 4]:
            self.effective_pressure = project3d(md, 'vector', self.effective_pressure, 'type', 'node', 'layer', 1)
            self.sheet_thickness = project3d(md, 'vector', self.sheet_thickness, 'type', 'node', 'layer', 1)
            self.rheology_A = project3d(md, 'vector', self.rheology_A, 'type', 'node', 'layer', 1)
            self.bump_height = project3d(md, 'vector', self.bump_height, 'type', 'node', 'layer', 1)
            self.bump_spacing = project3d(md, 'vector', self.bump_spacing, 'type', 'node', 'layer', 1)
        return self
    # }}}
    def checkconsistency(self, md, solution, analyses):  # {{{
        # Early return
        if 'StressbalanceAnalysis' not in analyses and 'ThermalAnalysis' not in analyses:
            return md
        md = checkfield(md, 'fieldname', 'friction.C', 'timeseries', 1, 'NaN', 1, 'Inf', 1)
        md = checkfield(md, 'fieldname', 'friction.zeta', 'numel', [1], '>', 0)
        md = checkfield(md, 'fieldname', 'friction.m', 'NaN', 1, 'Inf', 1, '>', 0., 'size', [md.mesh.numberofelements,1])
        md = checkfield(md, 'fieldname', 'friction.lambd', 'numel', [1], '>=', 0., '<=', 1.)
        md = checkfield(md, 'fieldname', 'friction.effective_pressure_limit', 'numel', [1], '>=', 0)
        md = checkfield(md, 'fieldname', 'friction.coupling', 'numel', [1], 'values', [0:4])
        md = checkfield(md, 'fieldname', 'friction.rheology_A', 'NaN', 1, 'Inf', 1, 'timeseries', 1, '>', 0.)
        md = checkfield(md, 'fieldname', 'friction.bump_height', 'NaN', 1, 'Inf', 1, 'timeseries', 1, '>', 0.)
        md = checkfield(md, 'fieldname', 'friction.bump_spacing', 'NaN', 1, 'Inf', 1, 'timeseries', 1, '>', 0.)
        if self.coupling in [3, 4]:
            md = checkfield(md, 'fieldname', 'friction.effective_pressure', 'NaN', 1, 'Inf', 1, 'timeseries', 1)
            md = checkfield(md, 'fieldname', 'friction.sheet_thickness', 'NaN', 1, 'Inf', 1, 'timeseries', 1)
        return md
    # }}}
    def marshall(self, prefix, md, fid):  # {{{
        yts = md.constants.yts

        WriteData(fid, prefix, 'name', 'md.friction.law', 'data', 16, 'format', 'Integer')
        WriteData(fid, prefix, 'class', 'friction', 'object', self, 'fieldname', 'C', 'format', 'DoubleMat', 'mattype', 1, 'timeserieslength', md.mesh.numberofvertices+1, 'yts', md.constants.yts)
        WriteData(fid, prefix, 'object', self, 'class', 'friction', 'fieldname', 'zeta', 'format', 'Double')
        WriteData(fid, prefix, 'class', 'friction', 'object', self, 'fieldname', 'm', 'format', 'DoubleMat', 'mattype', 2)
        WriteData(fid, prefix, 'object', self, 'class', 'friction', 'fieldname', 'lambd', 'format', 'Double')
        WriteData(fid, prefix, 'object', self, 'class', 'friction', 'fieldname', 'effective_pressure_limit', 'format', 'Double')
        WriteData(fid, prefix, 'class', 'friction', 'object', self, 'fieldname', 'coupling', 'format', 'Integer')
        WriteData(fid, prefix, 'class', 'friction', 'object', self, 'fieldname', 'rheology_A', 'format', 'DoubleMat', 'mattype', 1, 'timeserieslength', md.mesh.numberofvertices+1, 'yts', md.constants.yts)
        WriteData(fid, prefix, 'class', 'friction', 'object', self, 'fieldname', 'bump_height', 'format', 'DoubleMat', 'mattype', 1, 'timeserieslength', md.mesh.numberofvertices+1, 'yts', md.constants.yts)
     	WriteData(fid, prefix, 'class', 'friction', 'object', self, 'fieldname', 'bump_spacing', 'format', 'DoubleMat', 'mattype', 1, 'timeserieslength', md.mesh.numberofvertices+1, 'yts', md.constants.yts)
        if self.coupling in [3, 4]:
            WriteData(fid, prefix, 'class', 'friction', 'object', self, 'fieldname', 'effective_pressure', 'format', 'DoubleMat', 'mattype', 1, 'timeserieslength', md.mesh.numberofvertices+1, 'yts', md.constants.yts)
            WriteData(fid, prefix, 'class', 'friction', 'object', self, 'fieldname', 'sheet_thickness', 'format', 'DoubleMat', 'mattype', 1, 'timeserieslength', md.mesh.numberofvertices+1, 'yts', md.constants.yts)
    # }}}
