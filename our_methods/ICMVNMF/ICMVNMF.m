function [W,H,Hc,obj_all_final,obj_consis_final] = ICMVNMF(X,options)
obj_all_final = [];
obj_consis_final = [];
% modified from "DC_MVNMF".
% sum_v |Xv-WvHv|_F^2 + alpha*sum_v |Hv-HcGv'|_F^2
% + beta*sum_v tr(Hv*Lv*Hv')
% s.t. Wv,Hv >=0 
n_view = length(X);
for i = 1:n_view
    X{i} = X{i}';
    [mFea{i},nSmp{i}] = size(X{i});
end
nSmp_all = options.nSmp_all;

nSubSpace = options.nSubSpace;
dim = options.dim*nSubSpace;
alpha = options.alpha;
beta = options.beta;
G = options.G;

p = options.p;
%% load graph laplacian of all samples
if beta > 0
    for i = 1:n_view
        Sg{i} = sparse(beta*options.S{i});
        Dg{i} = spdiags(full(sum(Sg{i},2)),0,nSmp{i},nSmp{i});
        Lg{i} = Dg{i} - Sg{i};
    end
else
    for i = 1:n_view
        Lg{i} = zeros(nSmp{i},nSmp{i});
    end
end
%% initialize W{i} H{i} Hc
init_nmf = 0;
if ~init_nmf
    W = cell(1,n_view);
    H = cell(1,n_view);
    Hc = 0;
    for i = 1:n_view
        rand('seed',i*666);
        W{i} = rand(mFea{i},dim);
        H{i} = rand(dim,nSmp{i});
    end
    Hc = rand(dim,nSmp_all);
else
    opts_nmf = [];
    opts_nmf.maxIter = 200;
    opts_nmf.error = 1e-6;
    opts_nmf.nRepeat = 30;
    opts_nmf.minIter = 50;
    opts_nmf.meanFitRatio = 0.1;
    Hc = 0;
    for i = 1:n_view
        rand('seed',i*666);
        [UU,SS,VV] = svd(X{i});
        W{i} = abs(UU(:,1:5));
        [~,ind] = sort(diag(SS),'descend');
        H{i} = abs(SS(ind(1:dim),ind(1:dim))*VV(ind(1:dim),:));
        Hc = Hc + 1/n_view*H{i}*G{i};
    end
end
%% normalize W{i} H{i}
for v = 1:n_view
    Norm = 1;
    NormV = 0;
    [W{v},H{v}] = NormalizeUV(W{v}, H{v}, NormV, Norm);
end
%% calculate obj at step 0
obj_all = [];
obj_consis = [];
% % [obj,obj_consis_raw] = CalculateObj(X,W,H,G,alpha,beta,p,Lg);
% [obj,obj_consis_raw] = CalculateObj(X,W,H,G,Hc,alpha,beta,Lg);
% obj_all = [obj_all,obj];
% obj_consis = [obj_consis,obj_consis_raw];
%% start optimization
max_iter = options.max_iter;
iter = 0;
while  iter<=max_iter 
    iter = iter + 1;
    for v = 1:n_view
    %################# updata U1 and V1 ###################%
    %--------------------- update U1 ----------------------%
        XH = X{v}*H{v}'; % nk^2
        WHH = W{v}*H{v}*H{v}'; % 
        if alpha > 0
            normW = max(1e-15,sqrt(sum(W{v}.*W{v},1)));normW = normW';
            Qinv = spdiags(normW.^-1,0,dim,dim);
            HcGv = Hc*G{v}';
            QHH = Qinv*((HcGv*H{v}').*eye(dim));
            XH = XH + alpha*W{v}*QHH;
            Y1 = (H{v}*H{v}').*eye(dim);
            WHH = WHH + alpha*W{v}*Y1;
        end
        if beta > 0
            Y2n = (H{v}*Sg{v}*H{v}').*eye(dim);
            XH = XH + W{v}*Y2n;
            Y2p = (H{v}*Dg{v}*H{v}').*eye(dim);
            WHH = WHH + W{v}*Y2p;
        end

        W{v} = W{v}.*(XH./max(WHH,1e-10)); % 3mk
    %------------------- normalization ------------------------%
    % normalize the column vectors of W and consequently convey the
    % norm to the coefficient matrix H
        normW = max(1e-15,sqrt(sum(W{v}.*W{v},1)));normW = normW';
        W{v} = W{v}*spdiags(normW.^-1,0,dim,dim);
        H{v} = spdiags(normW,0,dim,dim)*H{v};
    %--------------------- update V1 ----------------------%
        WX = W{v}'*X{v}; % mnk or pk (p<<mn)
        WWH = W{v}'*W{v}*H{v}; % mk^2
        if alpha > 0
            HcGv = Hc*G{v}';
            WX = WX + alpha*HcGv;
            WWH = WWH + alpha*H{v};
        end
        if beta > 0 
            WX = WX + H{v}*Sg{v};
            WWH = WWH + H{v}*Dg{v};
        end

        H{v} = H{v}.*(WX./max(WWH,1e-10));
    end
    %--------------------- update Hc ----------------------%
    HG = 0;GG = 0;
    for i = 1:n_view
        HG = HG + H{i}*G{i};
        GG = GG + G{i}'*G{i};
    end
%     Hc = max(HG/GG,1e-10);
    Hc = Hc.*(HG./max(Hc*GG,1e-10));

% %     [newobj,obj_consis_raw] = CalculateObj_Hv_Hw(X,W,H,G,alpha,beta,p,Lg);
%     [newobj,obj_consis_raw] = CalculateObj(X,W,H,G,Hc,alpha,beta,Lg);
% %     differror = abs(newobj - objhistory(end))/abs(objhistory(end));
%     obj_all = [obj_all newobj]; %#ok<AGROW>
%     obj_consis = [obj_consis obj_consis_raw];
end
% obj_all_final = obj_all;
% obj_consis_final = obj_consis;
% obj_all_final = obj_all(end);
% obj_consis_final = obj_consis(end);

for v = 1:n_view
    Norm = 1;
    NormV = 0;
    [W{v},H{v}] = NormalizeUV(W{v}, H{v}, NormV, Norm);
end

end
%==========================================================================
function D = CalculateD(Z,p)
% ||Z||^p_2,p
% used in following paper:
% 2017-TNNLS-"robust structured nonnegative matrix factorization for 
% image representation"
D = diag(p./max(2*(sqrt(sum(Z.^2,1)).^(2-p)),1e-20));%
end

function [obj,obj_consis_raw] = CalculateObj(X,W,H,G,Hc,alpha,beta,Lg)
    n_view = length(X);
    
    obj_NMF = 0;
    for v = 1:n_view
        dX = W{v}*H{v}-X{v};
        obj_NMF = obj_NMF + sum(sum(dX.^2,1));
    end
    
    obj_consis = 0;
    if alpha > 0
        for v = 1:n_view
            obj_consis = obj_consis + sum(sum((H{v}-Hc*G{v}').^2));
        end
    end
    obj_consis_raw = obj_consis;
    obj_consis = alpha*obj_consis;

    obj_lap = 0;
    if beta > 0
        for v = 1:n_view
            obj_lap = obj_lap + sum(sum(H{v}.*(H{v}*Lg{v})));
        end
    end

    
    obj = obj_NMF + obj_consis + obj_lap;
end

function [obj,obj_consis_raw] = CalculateObj_Hv_Hw(X,W,H,G,alpha,beta,p,Lg)
    n_view = length(X);
    
    obj_NMF = 0;
    for v = 1:n_view
        dX = W{v}*H{v}-X{v};
        obj_NMF = obj_NMF + sum(sqrt(sum(dX.^2,1)).^p);
    end
    
    obj_consis = 0;
    if alpha > 0
        for v = 1:n_view
            L = 1:n_view;
            L(v) = [];
            for iv = L
                givi = sum(G{v}',2)+sum(G{iv}',2)-1;
                givi = max(givi,0);
                Aivi = repmat(givi,1,size(H{1},1))';
                Hivi = Aivi.*(H{v}/G{v}');
                Hci = Aivi.*(H{iv}/G{iv}');
                obj_consis = obj_consis + sum(sum((Hivi-Hci).^2));
            end
        end
    end
    obj_consis_raw = obj_consis;
    obj_consis = alpha*obj_consis;

    obj_lap = 0;
    if beta > 0
        for v = 1:n_view
            obj_lap = obj_lap + sum(sum(H{v}.*(H{v}*Lg{v})));
        end
    end
    
    obj = obj_NMF + obj_consis + obj_lap;
end

function [U, V] = NormalizeUV(U, V, NormV, Norm)
    K = size(U,2);
    if Norm == 2
        if NormV
            norms = max(1e-15,sqrt(sum(V.^2,1)));
            V = spdiags(norms.^-1,0,K,K)*V;
            U = U*spdiags(norms,0,K,K);
        else
            norms = max(1e-15,sqrt(sum(U.^2,1)))';
            U = U*spdiags(norms.^-1,0,K,K);
            V = spdiags(norms,0,K,K)*V;
        end
    else
        if NormV
            norms = max(1e-15,sum(abs(V),1));
            V = spdiags(norms.^-1,0,K,K)*V;
            U = U*spdiags(norms,0,K,K);
        else
            norms = max(1e-15,sum(abs(U),1))';
            U = U*spdiags(norms.^-1,0,K,K);
            V = spdiags(norms,0,K,K)*V;
        end
    end
end
