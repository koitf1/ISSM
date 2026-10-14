%FRICTIONLINCOMB class definition
%
%   Usage:
%      frictionlincomb=frictionlincomb();

classdef frictionlincomb
	properties (SetAccess=public) 
		C                        = NaN;
		Cmax                     = NaN;
		alpha                    = NaN;
		lambd                    = NaN;
		m                        = NaN;
		coupling                 = 0;
		effective_pressure       = NaN;
		sheet_thickness          = NaN;
		effective_pressure_limit = 0;
		rheology_A       	 = NaN;
		bump_height              = NaN;
		bump_spacing             = NaN;
	end
	methods
		function self = frictionlincomb(varargin) % {{{
			switch nargin
				case 0
					self=setdefaultparameters(self);
				case 1
					self=structtoobj(frictionlincomb(),varargin{1});
				otherwise
					error('constructor not supported');
			end
		end % }}}
		function self = extrude(self,md) % {{{
			self.C    = project3d(md,'vector',self.C,'type','node');
			self.Cmax = project3d(md,'vector',self.Cmax,'type','node');
			self.alpha = project3d(md,'vector',self.alpha,'type','node');
			self.m    = project3d(md,'vector',self.m,'type','element');
			self.rheology_A = project3d(md,'vector',self.rheology_A,'type','node','layer',1);
			self.bump_height = project3d(md,'vector',self.bump_height,'type','node','layer',1);
			self.bump_spacing = project3d(md,'vector',self.bump_spacing,'type','node','layer',1);
			if self.coupling==3 || self.coupling==4
				self.effective_pressure = project3d(md,'vector',self.effective_pressure,'type','node','layer',1);
				self.sheet_thickness = project3d(md,'vector',self.sheet_thickness,'type','node','layer',1);
			end
		end % }}}
		function self = setdefaultparameters(self) % {{{
		
         		self.coupling = 0;
			self.effective_pressure_limit = 0;
			self.alpha = 1e22;

		end % }}}
		function md = checkconsistency(self,md,solution,analyses) % {{{

			%Early return
			if ~ismember('StressbalanceAnalysis',analyses) & ~ismember('ThermalAnalysis',analyses), return; end
			md = checkfield(md,'fieldname','friction.C','timeseries',1,'NaN',1,'Inf',1);
			md = checkfield(md,'fieldname','friction.Cmax','timeseries',1,'NaN',1,'Inf',1);
			md = checkfield(md,'fieldname','friction.alpha','numel',[1],'>=',0);
			md = checkfield(md,'fieldname','friction.m','NaN',1,'Inf',1,'>',0.,'size',[md.mesh.numberofelements,1]);
			md = checkfield(md,'fieldname','friction.lambd','numel',[1],'>=',0.,'<=',1.);
			md = checkfield(md,'fieldname','friction.effective_pressure_limit','numel',[1],'>=',0);
         		md = checkfield(md,'fieldname','friction.coupling','numel',[1],'values',[0:4]);
         		md = checkfield(md,'fieldname','friction.rheology_A','NaN',1,'Inf',1,'timeseries',1,'>',0.);
         		md = checkfield(md,'fieldname','friction.bump_height','NaN',1,'Inf',1,'timeseries',1,'>',0.);
         		md = checkfield(md,'fieldname','friction.bump_spacing','NaN',1,'Inf',1,'timeseries',1,'>',0.);
         		if self.coupling==3 || self.coupling==4
         			md = checkfield(md,'fieldname','friction.effective_pressure','NaN',1,'Inf',1,'timeseries',1);
         			md = checkfield(md,'fieldname','friction.sheet_thickness','NaN',1,'Inf',1,'timeseries',1);
        		end
		end % }}}
		function disp(self) % {{{
			disp('linear combination friction law parameters:');
			disp('   friction law:');
			disp('                         xi      u_b                        1                 |u_b| ');
			disp('      tau_b = - Cmax Nh______  _____ + C^2 |u_b|^(m-1) u_b______, xi = alpha _______');
			disp('                        1+xi    |u_b|                      1+xi              Nh^(1/m)');
			disp(' ');
			disp('              |u_b|(h_r-tildeh)                                                 h_r ');
			disp('      Nh = (  __________________)^m, tildeh = lambda h + (1-lambda)  __________________________');
			disp('                 A l_r tildeh                                         1 + A l_r u_b / N^(1/m)');
			fielddisplay(self,'C','friction coefficient [SI]');
			fielddisplay(self,'Cmax','Iken''s bound (typically between 0.17 and 0.84) [SI]');
			fielddisplay(self,'alpha','degree that cavitation plays a role in the sliding regime');
			fielddisplay(self,'m','m exponent (generally taken as m = 1/n = 1/3)');
			fielddisplay(self,'lambd','parameter between 0 and 1 that controls the importance of the past state of the system (default 0 for complete effective pressure dependence)');
			fielddisplay(self,'rheology_A','ice flow parameter [Pa^3 s^(-1)]');
			fielddisplay(self,'bump_height','bedrock bump height [m]');
			fielddisplay(self,'bump_spacing','bedrock bump spacing [m]');
			fielddisplay(self,'effective_pressure','Effective Pressure for the forcing if not coupled [Pa]');
			fielddisplay(self,'sheet_thickness','hydrology sheet thickness for the forcing if not coupled [m]');
         		fielddisplay(self,'coupling','Coupling flag 0: uniform sheet (negative pressure ok, default), 1: ice pressure only, 2: water pressure assuming uniform sheet (no negative pressure), 3: use provided effective_pressure, 4: use coupled model (not implemented yet)');
			fielddisplay(self,'effective_pressure_limit','effective pressure limit type 1, do not allow N to fall below a certain limit: effective_pressure_limit*rho_ice*g*thickness (default 0)');
		end % }}}
		function marshall(self,prefix,md,fid) % {{{
			yts=md.constants.yts;

			WriteData(fid,prefix,'name','md.friction.law','data',17,'format','Integer');
			WriteData(fid,prefix,'class','friction','object',self,'fieldname','C','format','DoubleMat','mattype',1,'timeserieslength',md.mesh.numberofvertices+1,'yts',md.constants.yts);
			WriteData(fid,prefix,'class','friction','object',self,'fieldname','Cmax','format','DoubleMat','mattype',1,'timeserieslength',md.mesh.numberofvertices+1,'yts',md.constants.yts);
			WriteData(fid,prefix,'object',self,'class','friction','fieldname','alpha','format','Double');
			WriteData(fid,prefix,'class','friction','object',self,'fieldname','m','format','DoubleMat','mattype',2);
			WriteData(fid,prefix,'object',self,'class','friction','fieldname','lambd','format','Double');
			WriteData(fid,prefix,'class','friction','object',self,'fieldname','rheology_A','format','DoubleMat','mattype',1,'timeserieslength',md.mesh.numberofvertices+1,'yts',md.constants.yts);
         		WriteData(fid,prefix,'class','friction','object',self,'fieldname','bump_height','format','DoubleMat','mattype',1,'timeserieslength',md.mesh.numberofvertices+1,'yts',md.constants.yts);
         		WriteData(fid,prefix,'class','friction','object',self,'fieldname','bump_spacing','format','DoubleMat','mattype',1,'timeserieslength',md.mesh.numberofvertices+1,'yts',md.constants.yts);
			WriteData(fid,prefix,'object',self,'class','friction','fieldname','effective_pressure_limit','format','Double');
         		WriteData(fid,prefix,'class','friction','object',self,'fieldname','coupling','format','Integer');
         		if self.coupling==3 || self.coupling==4
            			WriteData(fid,prefix,'class','friction','object',self,'fieldname','effective_pressure','format','DoubleMat','mattype',1,'timeserieslength',md.mesh.numberofvertices+1,'yts',md.constants.yts);
            			WriteData(fid,prefix,'class','friction','object',self,'fieldname','sheet_thickness','format','DoubleMat','mattype',1,'timeserieslength',md.mesh.numberofvertices+1,'yts',md.constants.yts);
         		end
		end % }}}
	end
end
