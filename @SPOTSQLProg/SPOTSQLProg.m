classdef SPOTSQLProg
    properties 
        % Developer's Notes about Internal Representation:
        % 
        % The program consists of a collection of variable dimensions:
        % 
        % name -- Character prefix for variables from the program.
        %
        %
        % posNum  -- 1-by-1 Positive integer (number of non-negative variables).
        % freeNum -- 1-by-1 Positive integer (number of non-negative variables).
        % psdDim -- Npsd-by-1 array of positive integers.  Each represents
        %                     psdDim(i)-by-psdDim(i) dim. variable.
        % lorDim -- Nlor-by-1 array of positive integers.  Size of
        %                     Lorentz cones (n indicates x(1)^2 >=
        %                     sum_i=2^n x(i)^2 )
        % rlorDim -- Nrlor-by-1 array of positive integers, similar
        %                     for rotated Lorentz cones.
        %
        % Variables are named @psdi, @lori, @posi @rlri, where @ is
        % replaced by 'name' and 'i' is a running counter.
        %
        %
        %
        name = '@';
        
        posNum  = 0;
        freeNum = 0;
        psdDim  = [];
        lorDim  = [];
        rlorDim = [];
        
        psdCnst = {};
        lorCnst = {};
        posCnst = [];
        
        equations = [];
    end

    methods (Static)
        function n = psdDimToNo(d)
            n=(d+1).*d/2;
        end
        
        function [d,v] = psdNoToDim(n)
        %
        %  0 = d^2 + d - 2n
        %  (sqrt(1 + 8n) - 1)/2
        %
            d=round((sqrt(1+8*n)-1)/2);
            if SPOTSQLProg.psdDimToNo(d) ~= n
                d = NaN;
                v = 0;
            else
                v = 1;
            end
        end

    end

    
    methods ( Access = private )        
%  These private functions define the names of variables
%  generated by the program.

        function nm = freeName(pr)
            nm = [pr.name 'fr'];
        end
        function nm = posName(pr)
            nm = [pr.name 'pos'];
        end
        function nm = psdName(pr)
            nm = [pr.name 'psd'];
        end
        function nm = lorName(pr)
            nm = [pr.name 'lor'];
        end
        function nm = rlorName(pr)
            nm = [pr.name 'rlr'];
        end


        
%  Generate variables of a given type.        
        function f = freeVariables(pr)
            f = msspoly(pr.freeName,pr.numFree);
        end
        function p = posVariables(pr)
            p = msspoly(pr.posName,pr.numPos);
        end
        function l = lorVariables(pr)
            l = msspoly(pr.lorName,pr.numLor);
        end
        function r = rlorVariables(pr)
            r = msspoly(pr.rlorName,pr.numRLor);
        end
        function p = psdVariables(pr)
            p = msspoly(pr.psdName,pr.numPSD);
        end
        

        
        function flag = realLinearInDec(pr,exp)
            [x,pow,Coeff] = decomp(exp);
            [~,xid] = isfree(x);
            [~,vid] = isfree(pr.variables);
            flag = ~(any(mss_match(vid,xid) == 0) | ...
                     any(pow(:) > 1) | ...
                     any(imag(Coeff(:)) ~= 0));
        end
        
        function flag = legalEq(pr,eq)
            if ~isa(eq,'msspoly')
                flag = 0;
            else
                flag = realLinearInDec(pr,eq);
            end
        end
    end
    methods
        
        function pr=SPOTSQLProg(name)
        % pr=SPOTSQLProg(prefix)
        %
        % prefix -- Scalar character, legal name for msspoly.
        %
        % Returns:
        % pr   -- New program, decision variables begin with
        %         the character prefix.
        %
        %
        % SPOTSQLProg objects model SDP/SOCP/LP cone programs.
        %
        %    The feasible set of these programs is represented in a
        %    mixture of standard primal and standard dual form:
        %
        %    (F)  x in K1,  y free,
        %         A1.x + A2.y = b,
        %         D1.x + D2.y + e in K2,
        %
        %    where K1 and K2 are products of the SDP, SOCP and LP
        %    cones of various dimensions.
        %
        %    After the feasible set has been constructed, an
        %    optimization problem can be solved via prg.optimze():
        %   
        %    minimize c'x + f'y  subj. to. (F)
        %
        %    Solution of these problems by primal dual solvers such
        %    as SeDuMi or SDPT3 requires converting the problem to
        %    standard primal or dual form.  The choice of which
        %    conversion to apply can be forced as an optimizatio parameter.
        %
        %
        %
            if nargin > 0
                if ~ischar(name) || length(name) > 1
                    error('Program name must be a scalar character.');
                else
                    msspoly(name);
                end
                pr.name = name;
            end
        end
        
        
        function v = variables(pr)
        % v = variables(pr)
        % v -- msspoly column of primal variables for the program pr.
            v = [ pr.freeVariables
                  pr.posVariables
                  pr.lorVariables
                  pr.rlorVariables
                  pr.psdVariables];
        end
        
        function n = numPos(pr)
            n = pr.posNum;
        end
        function n = numFree(pr)
            n = pr.freeNum;
        end
        function n = numPSD(pr)
            n = sum(SPOTSQLProg.psdDimToNo(pr.psdDim));
        end
        function n = numLor(pr)
            n = sum(pr.lorDim);
        end
        function n = numRLor(pr)
            n = sum(pr.rlorDim);
        end
        function m = numEq(pr)
            m = length(pr.equations);
        end
        
        function [pr,Q] = newPSD(pr,dim)
            if ~spot_hasSize(dim,[1 1]) || ~spot_isIntGE(dim,1)
                error('Dimension must be scalar positive integer.');
            end
            n = SPOTSQLProg.psdDimToNo(dim);
            
            Q = mss_v2s(msspoly(pr.psdName,[n pr.numPSD]));
            
            pr.psdDim = [pr.psdDim dim];
        end
        
        function [pr,Qs] = newBlkPSD(pr,dim)
            if ~spot_hasSize(dim,[1 2]) || ~spot_isIntGE(dim,1)
                error('Dimension must be 1x2 positive integer.');
            end
            
            n = SPOTSQLProg.psdDimToNo(dim(1));
            
            Qs = reshape(msspoly(pr.psdName,[n*dim(2) pr.numPSD]),n,dim(2));
            pr.psdDim = [pr.psdDim dim(1)*ones(1,dim(2))];
        end
        
        function [pr,p] = newPos(pr,dim)
            if ~spot_hasSize(dim,[1 1]) || ~spot_isIntGE(dim,1)
                error('Dimension must be scalar positive integer.');
            end
            
            p = msspoly(pr.posName,[dim pr.numPos]);
            
            pr.posNum = pr.posNum+dim;
        end
        
        function [pr,f] = newFree(pr,dim)
            if spot_hasSize(dim,[1 1])
                dim = [ dim 1];
            end
            if ~spot_hasSize(dim,[1 2]) || ~spot_isIntGE(dim,1)
                error('Dimension must be 1-by-1 or 1-by-2 positive integer.');
            end
            
            f = reshape(msspoly(pr.freeName,[prod(dim) pr.numFree]),dim);
            
            pr.freeNum = pr.freeNum+prod(dim);
        end
        
        function [pr,l] = newLor(pr,dim)
            if spot_hasSize(dim,[1 1]), dim = [dim 1]; end
            if ~spot_hasSize(dim,[1 2]) || ~spot_isIntGE(dim,1)
                error('Dimension must be 1x2 positive integer.');
            end
            
            l = reshape(msspoly(pr.lorName,[prod(dim) pr.numLor]),dim(1),dim(2));
            
            pr.lorDim = [pr.lorDim dim(1)*ones(1,dim(2))];
        end
        
        function [pr,r] = newRLor(pr,dim)
            if spot_hasSize(dim,[1 1]), dim = [dim 1]; end
            if ~spot_hasSize(dim,[1 2]) || ~spot_isIntGE(dim,1)
                error('Dimension must be 1x2 positive integer.');
            end
            
            r = reshape(msspoly(pr.rlorName,[prod(dim) pr.numRLor]),dim(1),dim(2));
            
            pr.rlorDim = [pr.rlorDim dim(1)*ones(1,dim(2))];
        end
        
        function [pr] = withEqs(pr,eq)
            if ~pr.legalEq(eq)
                error(['Equations must be an msspoly linear in ' ...
                       'decision parameters.']);
            end
            eq = eq(:);
            
            pr.equations = [pr.equations ; eq];
        end
         
        %-- 
        function [pr] = withPos(pr,exp)
            if ~isa(exp,'msspoly')
                error('Argument must be a column of msspoly expressions.');
            end
            exp = exp(:);
            
            pr.posCnst = [pr.posCnst ; exp];
        end
        
        function [pr] = withPSD(pr,exp)
            if ~isa(exp,'msspoly') || size(exp,1) ~= size(exp,2)
                error('Argument must be a square msspoly.');
            end
            
            if size(exp,1) == 1
                [pr,l] = pr.withPos(pr,exp);
            else
                exp = mss_s2v(exp);
                pr.psdCnst{end+1} = exp;
            end
        end
        
        function [pr] = withBlkPSD(pr,exp)
            if ~isa(exp,'msspoly')
                error('Argument must be an msspoly.');
            end
            [~,v] = SPOTSQLProg.psdNoToDim(size(exp,1));
            if ~v
                error('Argument wrong size.');
            end
            
            if size(exp,1) == 1
                pr = pr.withPos(pr,exp);
            else
                pr.psdCnst{end+1} = exp;
            end
        end
        
        function [pr] = withLor(pr,exp)
            if ~isa(exp,'msspoly')
                error('Argument must be an msspoly.');
            end
            
            if size(exp,1) == 1
                [pr] = pr.withPos(exp);
            else
                pr.lorCnst{end+1} = exp;
            end
        end
        
        function [spPrg,G,h] = standardPrimalWithFree(prg)
        %
        %  [spPrg,G,h] = standardPrimalWithFree(prg)
        %
        %  Converts a program into the standard primal with free
        %  variables form via the introduction of slack variables.
        %
        %  The matrices G,h are constructed so that
        %
        %  prg.variables = G*spPrg.variables + h.
        %
            spPrg = prg;
            
            if length(spPrg.posCnst) > 0
                [spPrg,slack] = spPrg.newPos(length(spPrg.posCnst));
                spPrg = spPrg.withEqs(spPrg.posCnst - slack);
                spPrg.posCnst = {};
            end
            
            for i = 1:length(spPrg.psdCnst)
                cnst = spPrg.psdCnst{i};

                [spPrg,slack] = spPrg.newBlkPSD([SPOTSQLProg.psdNoToDim(size(cnst,1)) size(cnst,2)]);
                spPrg = spPrg.withEqs(cnst - slack);
            end            
            spPrg.psdCnst = {};
            
            for i = 1:length(spPrg.lorCnst)
                cnst = spPrg.lorCnst{i};

                [spPrg,slack] = spPrg.newLor(size(cnst,1));
                spPrg = spPrg.withEqs(cnst - slack);
            end            
            spPrg.lorCnst = {};
            
            h = zeros(size(prg.variables));
            
            [var,pow,Coeff] = decomp(spPrg.variables);

            mtch = match(var,prg.variables);
            
            G = Coeff(:,mtch)';
            
        end
        
        
        function [prgout,G,h] = standardDual(prg)
        %
        %  [spPrg,G,h] = standardDual(prg)
        %
        %  Converts a program into the standard dual form.
        %
        %  Conic variables are replaced by new free variables.
        %
        %  Then, a lower dimensional parameterization:
        %
        %  [ x; y] = Gz + h
        %
        %  is found with [A1 A2] h = b, [A1 A2] G = 0.
        %
        %
            
            function prgout = moveConstraints(prgout,prg,free)
                if ~isempty(prg.posCnst)
                    prgout = prgout.withPos(subs(prg.posCnst,prg.variables,free));
                end
            end
            
            
            function prgout = removeConic(prg)
                prgout = SPOTSQLProg(prg.name);
                [prgout,free] = prgout.newFree(length(prg.variables));
            
                if prg.numPos > 0
                    mtch = match(prg.variables,prg.posVariables);
                    prgout = prgout.withPos(free(mtch));
                end
                
                if prg.numLor > 0
                    error('Did not support Lorentz cone yet.');
                end
                
                prgout = moveConstraints(prgout,prg,free);
                prgout = prgout.withEqs(subs(prg.equations,prg.variables,free));
            end
            
            function prgout = removeEquality(prg)
            % Now resolve equality constraints.
                if length(prg.equations) == 0,
                    prgout = prg;
                    G = speye(prg.numFree);
                    h = sparse([],[],[],prg.numFree,1);
                    return;
                end
                
                prgout = SPOTSQLProg(prg.name);

                [A,b] = SPOTSQLProg.decompLinear(prg.equations,prg.variables);
            
                % TODO: Return to this setting to preserve sparsity.
                
                h = A\b;
                
                [Q,R] = qr(A');
                n = max(find(sum(abs(R),2)));
                G = Q(:,n+1:end); % New basis

                [prgout,z] = prgout.newFree(size(G,2));
                
                prgout = moveConstraints(prgout,prg,G*z+h);
            end
            
            prgout = removeConic(prg);
            prgout = removeEquality(prgout);
          
        end
        
        
        function sol = minimizePrimalForm(pr,objective,options)
            if nargin < 2, objective = 0; end
            if nargin < 3, options = struct('fid',0); end

            objective = msspoly(objective);
            if ~realLinearInDec(pr,objective)
                error('Objective must be real and linear in dec. variables.');
            end
            
            user_variables = pr.variables;
            
            [pr,G,h] = pr.standardPrimalWithFree();

            %  First, construct structure with counts of SeDuMi
            %  variables.
            K = struct();
            K.f = pr.freeNum;
            K.l = pr.posNum;
            K.q = pr.lorDim;
            K.r = pr.rlorDim;
            K.s = pr.psdDim;
            
            KvarCnt = K.f+K.l+sum(K.q)+sum(K.r)+sum(K.s.^2);
            
            
            v = [ pr.freeVariables
                  pr.posVariables
                  pr.lorVariables
                  pr.rlorVariables ];
            
            vpsd = pr.psdVariables;
            
            vall = [v;vpsd];
 
            [psdVarNo] = SPOTSQLProg.upperTriToFullVarNo(length(vpsd),pr.psdDim);
            
            varNo = [ 1:length(v) length(v)+psdVarNo];
            
           [A,b] = SPOTSQLProg.linearToSedumi(pr.equations,vall,varNo,KvarCnt);
           [c,~] = SPOTSQLProg.linearToSedumi(objective,vall,varNo,KvarCnt);

           [x,y,info] = sedumi(A,b,c,K,options);
           
           if info.pinf, 
               primalSol = NaN*ones(size(length(varNo),1));
           else
               primalSol = x(varNo);
           end
           
           primalSol = G*primalSol + h;
           
           sol = SPOTSQLSoln(pr,info,user_variables,primalSol);
       end
       
       function sol = minimizeDualForm(pr,objective,options)
            if nargin < 3, options = struct(); end
            if ~isfield(options,'solver'),
                options.solver = 'sedumi';
            end
            if ~isfield(options,'solver_options')
                if strcmp(options.solver,'sedumi')
                    options.solver_options = struct('fid',0);
                end
            end
            user_variables = pr.variables;
            
            objective = msspoly(objective);
            if ~realLinearInDec(pr,objective)
                error('Objective must be real and linear in dec. variables.');
            end
            
             if ~SPOTSQLProg.isStandardDualProg(pr)
               error(['Right now the program must be in standard dual ' ...
                        'format.']);

               [pr,G,h] = pr.standardDual();
            else
                G = speye(size(user_variables,1));
                h = sparse([],[],[],size(user_variables,1),size(user_variables,2));
            end

            objective = subs(objective,user_variables,G*pr.variables+h);

            % minimize b'y
            %          c-A'y in K.
            %
            % (1) Decide on the appropriate cone sizes.
            % (2) Construct A, c.
            
            %  First, construct structure with counts of SeDuMi
            %  variables.
            K = struct();
            K.f = 0;
            K.r = 0;
            
            pos = pr.posCnst;
            K.l = length(pr.posCnst);
            
            K.q = [];
            lor = [];
            for i = 1:length(pr.lorCnst)
                lor = [ lor ; pr.lorCnst{i}(:) ];
                K.q = [ K.q size(pr.lorCnst{i},1)*ones(1,size(pr.lorCnst{i},2))];
            end
            
            v = [ pos ; lor ];

            K.s = [];
            vpsd = [];
            for i = 1:length(pr.psdCnst)
                vpsd = [ vpsd ; pr.psdCnst{i}(:) ];
                K.s = [ K.s SPOTSQLProg.psdNoToDim(size(pr.psdCnst{i},1))*ones(1,size(pr.psdCnst{i},2))];
            end
            
            KvarCnt = K.f+K.l+sum(K.q)+sum(K.r)+sum(K.s.^2);
            
            [psdVarNo,psdVarNoSymm] = SPOTSQLProg.upperTriToFullVarNo(length(vpsd),K.s);
            
            varNo = [ 1:length(v) length(v)+psdVarNo];
            varNoSymm = [ 1:length(v) length(v)+psdVarNoSymm];
            varNoDiag = varNo(find(varNo == varNoSymm));
            
            
            %  I need to isolate the term:  c - A'y in K where K is
            %  the cone of the above dimensions.
            
            vall = [ v ; vpsd ];
            
            [mAT,cm] = SPOTSQLProg.decompLinear(vall,pr.variables);
            [b,~]   = SPOTSQLProg.decompLinear(objective,pr.variables);
            b = -b.';
            
            [i,j,s] = find(mAT);

            mAT = sparse(varNo(i),j,s,KvarCnt,size(mAT,2));
            keep = varNo(i) ~= varNoSymm(i);
            mAT = mAT+sparse(varNoSymm(i(keep)),...
                             j(keep),s(keep),KvarCnt,size(mAT,2));

            [i,j,s] = find(-cm);
            c = sparse(varNo(i),j,s,KvarCnt,1);
            keep = varNo(i) ~= varNoSymm(i);
            c = c + sparse(varNoSymm(i(keep)),j(keep),s(keep),KvarCnt,1);
            
            if strcmp(options.solver,'sedumi')
                [x,y,info] = sedumi(-mAT.',b,c,K,options.solver_options);
            elseif strcmp(options.solver,'sdpnal')
                [blk,Asdpt,Csdpt,bsdpt] = read_sedumi(-mAT.',b,c,K);
                [obj,X,y,Z,infosdpt] = sdpnal(blk,Asdpt,Csdpt,bsdpt);
                info = struct('pinf',infosdpt.termcode == 1,...
                              'dinf',infosdpt.termcode == 2);

            else
                error(['Unknown solver: ' options.solver]);
            end

            if info.dinf || info.pinf,
                primalSol = NaN*ones(size(pr.variables,1),1);
            else
                primalSol = y;
            end

            sol = SPOTSQLSoln(pr,info,user_variables,G*primalSol+h);
        end
    end
       
           
    methods (Static, Access = private)
        
        function f = isStandardDualProg(prg)
            f = isa(prg,'SPOTSQLProg') && ...
                isempty(prg.equations) && ...
                prg.numPos == 0 && ...
                prg.numPSD == 0 && ...
                prg.numLor == 0;
        end
        
        
        function [A,b] = decompLinear(lin,vall)
            [veq,peq,Ceq] = decomp(lin);
            constant = ~any(peq~=0,2);%all(peq == 0,2);
            cnsti = find(constant);
            

            b = -Ceq(:,cnsti);
            Aeq = Ceq(:,~constant)*peq(~constant,:);
            
                        
            veqIndices = match(vall,veq);
            
            % T*vall = veq;
            T = sparse(1:length(veq),veqIndices,ones(length(veq),1),length(veq),length(vall));
            
            A = Aeq*T;

        end
        
        function [As,bs] = linearToSedumi(lin,vall,varNo,KvarCnt)
            [A,bs] = SPOTSQLProg.decompLinear(lin,vall);
            
            [i,j,s] = find(A);
            
            As = sparse(i,varNo(j),s,size(A,1),KvarCnt);
        end
        
        function [psdVarNo,psdVarNoSymm] = upperTriToFullVarNo(npsd,psdDim)
        % Assign column numbers to v.
            psdVarNo = zeros(1,npsd);
            psdVarNoSymm = zeros(1,npsd);
            psdVarOff = 0;    % Progress in variables, storing
                              % upper triangle.
            psdRedVarOff = 0; % Progress in variables, storing
                              % entire matrix.
            for i = 1:length(psdDim)
                n = psdDim(i);
                m = n*(n+1)/2;
                psdVarNo(psdVarOff + (1:m)) = psdRedVarOff+mss_s2v(reshape(1:n^2,n,n));
                psdVarNoSymm(psdVarOff + (1:m)) = psdRedVarOff+mss_s2v(reshape(1:n^2,n,n)');
                psdVarOff = psdVarOff + m;
                psdRedVarOff = psdRedVarOff + n^2;
            end

        end
       
    end
end