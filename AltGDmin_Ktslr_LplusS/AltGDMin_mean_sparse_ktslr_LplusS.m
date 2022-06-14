clc;
clear all;close all;
global n1 n2 n mk m  S2 gg q  jj n3 kk;
%filenames=  {'Cardiac_ocmr_data.mat'} ;
%filenames=  {'CSM.mat'} ;
%filenames=  {'Pincat.mat','brain_T2_T1.mat','speech_seq.mat','Cardiac_ocmr_data.mat','FB_ungated.mat'}%,'FB_ungated.mat',,'image_xyt'}  {'Cardiac_ocmr_data.mat'}%; %Cardiac'FB_ungated.mat',

filenames={'lowres_speech.mat'}%
%filenames=  {'freebreathing_ungated_Cardiac_cine_Cartesian.mat'} ;
%filenames={'Pincat.mat'};
%filenames={'brain_T2_T1.mat'}%,'lowres_speech.mat'};
%filenames={'image_xyt'};
%filenames={'lowres_speech.mat'};
ktslr=0;
ra=[];
rb=[];
STwm= 0;
ST2=0;
ST3=0;
STwithmean= 0;
STwithmeanLS =0;
AltLS_mod =1;
AltLS= 0;
Alt=0;
Altsp=0;
ST_noU=0;
Dataset=[];

[fid,msg] = fopen('Comparison.txt','wt');
fprintf(fid, '%s(%s) & %s & %s &  %s &  %s &  %s    \n','Dataset','Radial','Ktslr','LplusS','AltGDMin','AltGDMin MRI','AltGDMin Sparse');
for jj = 1:1:numel(filenames)
    S = load(filenames{jj});
    X=cell2mat(struct2cell(S));
    [~,name,~] = fileparts(filenames{jj});% Best to load into an output variable.
    radial=[8];
    x=X;
    save('C:\Users\sbabu\Desktop\Results\low_res_8\X_true.mat', 'x');
    x=double(x);
    [n1,n2,q]=size(x);
    n3=q;
    X1=reshape(x,[n1*n2,q]);
    n=n1*n2;
    Table = cell(length(radial)*numel(filenames), 11);
    Error_Ktslr=[];
    Time_Ktslr=[];
    Time_LSparse=[];
    Error_LSparse=[];
    Error_GD_Sparse=[];
    Time_GD_Sparse=[];
    for ii=1:1:length(radial)
        GD_MLS_time=0;
        GD_MLS_error=0;
        %  [mask] = goldenangle(n1,n2,q,radial(ii));%load('ocmr_test_kspace_mask_modlRecon_16lines.mat','mask_ocmr');
        %[mask] = load('ocmr_test_kspace_mask_modlRecon_16lines.mat','mask_ocmr');
        %mask=cell2mat(struct2cell(mask));%goldencart(n1,n2,q,radial(ii));
        [mask]=goldencart(n1,n2,q,radial(ii));
        %[mask]=strucrand(n1,n2,q,radial(ii));
        % mask2=cell2mat(struct2cell(mask2));
        mask = fftshift(fftshift(mask,1),2);
        Samp_loc=double(find(logical(mask)));
        mask3=reshape(mask,[n1*n2, q]);
        mk=[];
        for i=1:1:q
            mk(i)=length(find(logical(mask3(:,i))));
            S2(1:mk(i),i)=double(find(logical(mask3(:,i))));
        end
        m=max(mk);
        Y=zeros(m,q);
        for k=1:1:q
            ksc = reshape( fft2( reshape(X1(:,k), [n1 n2]) ), [n,1]) ;
            Y(1:mk(k),k)=double(ksc(S2(1:mk(k),k)));
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Ktslr %%%%%%%%%%%%%%%%%%%%%%%%%%
        S=find(mask~=0);
       % load('ktslr/');
        %%  Define the forward and backward operators A and Atranspose (At)
        Akt = @(z)A_fhp3D(z,S,n1,n2,q); % The forward Fourier sampling operator
        Aktt=@(z)At_fhp3D(z,S,n1,n2,q); % The backward Fourier sampling operator
        step_size = [1,1,1];
        [D,Dt] = defDDt(step_size);
        %% First guess, direct IFFT
        b = Akt(x);
        tic;
        x_init = Aktt(b);
        mu1 =1e-10; % Regularization parameter for schatten p-norm
        mu2 =4e-9; % Reg. parameter for spatiotemporal TV norm * Note: temporal wt weighted 10 times higher than spatial weight (see DefDDtmod.m)
        opts.mu1 = mu1;
        opts.mu2 = mu2;
        opts.p=0.1; % The value of p in Schatten p-norm; p=0.1: non convex; p = 1: convex
        [~,sq,~]=givefastSVD(reshape(x_init, n1*n2,q)); % find the singular values of the initial guess
        opts.beta1=10./max(sq(:));% The continuation parameter for low rank norm; initialize it as 1./max(singular value of x_init)
        opts.beta2=10./max(abs(x_init(:))); % The continuation parameter for the TV norm; Initialize it as 1./max((x_init(:)))
        opts.beta1rate = 50; % The continuation parametr increment for low rank norm
        opts.beta2rate = 25; % similar increment for TV norm
        opts.outer_iter =15; % no of outer iterations - INCREASE THIS TO BE CONSERVATIVE
        opts.inner_iter = 50; % no of inner iterations
        [Xhat_ktslr,cost,opts] = minSNandTV(Akt,Aktt,D,Dt,x_init,b,1,opts);
        %save('C:\Users\sbabu\Desktop\Mini-Batch\Mini_Batch_MEC_Sparse\golden_angle_and_radial_comparison\Xhat_ktslr.mat', 'Xhat_ktslr');
        Time_Ktslr=toc;
        Error_Ktslr= RMSE_modi(Xhat_ktslr,x);
        similarity_index=[];
        for i =1:1:q
            mssim=ssim(abs(Xhat_ktslr(:,:,i)/max(max(Xhat_ktslr(:,:,i)))),abs(x(:,:,i)/max(max(x(:,:,i)))));
            similarity_index(i)=mssim;
        end
        sim_Ktslr=min(similarity_index)
        save('C:\Users\sbabu\Desktop\Results\low_res_8\Xhat_ktslr.mat', 'Xhat_ktslr');
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%% LplusS %%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        param.Samp_loc=Samp_loc;
        A = @(z)A_fhp3D(z, Samp_loc,n1,n2,q);
        At = @(z) At_fhp3D(z, Samp_loc, n1,n2,q);
        param.A=A;
        param.At=At;
        param.d = A(X(:,:,1:q));
        param.T=TempFFT(3);
        tic;
        param.lambda_L=0.01;
        param.lambda_S=0.01;
        param.nite=50;
        param.tol=0.0025;
        M=At(param.d);
        
        M=reshape(M,[n1*n2,q]);
        Lpre=M;
        S=zeros(n1*n2,q);
        ite=0;
        while(1),
            ite=ite+1;
            % low-rank update
            M0=M;
            [Ut,St,Vt]=svd(M-S,0);
            St=diag(SoftThresh(diag(St),St(1)*param.lambda_L));
            L=Ut*St*Vt';
            % sparse update
            S=reshape(param.T'*(SoftThresh(param.T*reshape(M-Lpre,[n1,n2,q]),param.lambda_S)),[n1*n2,q]);
            % data consistency
            resk=param.A(reshape(L+S,[n1,n2,q]))-param.d;
            M=L+S-reshape(param.At(resk),[n1*n2,q]);
            % L_{k-1} for the next iteration
            Lpre=L;
            % print cost function and solution update
            tmp2=param.T*reshape(S,[n1,n2,q]);
            % stopping criteria
            if (ite > param.nite) || (norm(M(:)-M0(:))<param.tol*norm(M0(:))), break;end
        end
        Xhat_LpS1=L+S;
        Xhat_LpS=reshape(Xhat_LpS1,[n1,n2,q]);
        %         save('C:\Users\sbabu\Desktop\Mini-Batch\Mini_Batch_MEC_Sparse\low_res_result\LplusS.mat', 'Xhat');
        Time_LSparse= toc;
        Error_LSparse=RMSE_modi(Xhat_LpS,x);
        similarity_index=[];
        for i =1:1:q
            mssim=ssim(abs(Xhat_LpS(:,:,i)/max(max(Xhat_LpS(:,:,i)))),abs(x(:,:,i)/max(max(x(:,:,i)))));
            similarity_index(i)=mssim;
        end
        sim_LpS=min(similarity_index)
        save('C:\Users\sbabu\Desktop\Results\low_res_8\Xhat_LpS.mat', 'Xhat_LpS');
        %save('C:\Users\sbabu\Desktop\Mini-Batch\Mini_Batch_MEC_Sparse\golden_angle_and_radial_comparison\Xhat_LpS.mat', 'Xhat_LpS');
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%% AltgdMin + Sparse %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%% Mean +LowRank
        gg=mk(1:q);
        m=max(gg);
        Y=Y(1:m,1:q);
        Xhat1=[];
        L=[];
        T=70;
        pp=q;
        tic;
        [Xbar_hat,flag,resNE,iter] = cgls(@Afft,@Att, Y,0,1e-36,10);
        Ybar_hat=Afft(Xbar_hat);
        %         for i=1:1:q
        %             X_new(:,i)=Xbar_hat;
        %         end
        %         X_new_vec=reshape(X_new,[n1,n2,q])
        %         RMSE_modi(X_new_vec,x)
        Ybar_hat=reshape(Ybar_hat,[m,q]);
        Yinter=Y-Ybar_hat;
        [Uhat]=initAltGDMin(Yinter);
        [Uhat2, Bhat2]=GDMin_wi(T,Uhat,Yinter);
        xT=Uhat2*Bhat2;
        L(:,1:q)=xT+Xbar_hat;
%         %         X_new_vec=reshape(L,[n1,n2,q])
%         %         RMSE_modi(X_new_vec,x)
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %          Ymec=Y-Afft(L);
        %             for kk=1:1:q
        %                 E_mec(:,kk)=cgls_modi(@Afft_modi,@At_modi, Ymec(:,kk) ,0,1e-6,10);
        %             end
        %             Xrec=L+E_mec;
        %             Xhat_vec=reshape(Xrec,[n1, n2,q]);
        %             time=toc;
        %             RMSE_modi(Xhat_vec,x)
        
        
        param.Samp_loc=Samp_loc;
        A = @(z)A_fhp3D(z, Samp_loc,n1,n2,q);
        At = @(z) At_fhp3D(z, Samp_loc, n1,n2,q);
        param.A=A;
        param.At=At;
        param.d = A(X(:,:,1:q));
        param.T=TempFFT(3);
        param.lambda_L=0.01;
        
        param.nite=10;
        param.tol=0.0025;
        M=At(param.d);
        M=reshape(M,[n1*n2,q]);
        Lpre=M;
        S=zeros(n1*n2,q);
        param.lambda_S=0.001*max(max(abs(M-L)));
        ite=0;
        while(1)
            ite=ite+1;
            M0=M;
            % sparse update
            S=reshape(param.T'*(SoftThresh(param.T*reshape(M-Lpre,[n1,n2,q]),param.lambda_S)),[n1*n2,q]);
            % data consistency
            resk=param.A(reshape(L+S,[n1,n2,q]))-param.d;
            M=L+S-reshape(param.At(resk),[n1*n2,q]);
            Lpre=L;
            tmp2=param.T*reshape(S,[n1,n2,q]);
            if (ite > param.nite) || (norm(M(:)-M0(:))<param.tol*norm(M0(:))), break;end
        end
        Xhat_MGDS1=L+S;
        Xhat_MGDS=reshape(Xhat_MGDS1,n1,n2,q);
        Time_GD_Sparse=  toc;
        save('C:\Users\sbabu\Desktop\Results\low_res_8\Xhat_MGDS.mat', 'Xhat_MGDS');
        % Time_GD_Sparse= [Time_GD_Sparse, toc];
        Error_GD_Sparse=RMSE_modi(Xhat_MGDS,x);
        similarity_index=[];
        for i =1:1:q
            mssim=ssim(abs(Xhat_MGDS(:,:,i)/max(max(Xhat_MGDS(:,:,i)))),abs(x(:,:,i)/max(max(x(:,:,i)))));
            similarity_index(i)=mssim;
        end
        sim_MGDS=min(similarity_index)
     %   %filename(ii)=name;
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%% AltgdMin + MEC %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%% Mean +LowRank
        gg=mk(1:q);
        m=max(gg);
        Y=Y(1:m,1:q);
        Xhat1=[];
        L=[];
        T=70;
        pp=q;
        tic;
        [Xbar_hat,flag,resNE,iter] = cgls(@Afft,@Att, Y,0,1e-36,10);
        Ybar_hat=Afft(Xbar_hat);
        %         for i=1:1:q
        %             X_new(:,i)=Xbar_hat;
        %         end
        %         X_new_vec=reshape(X_new,[n1,n2,q])
        %         RMSE_modi(X_new_vec,x)
        Ybar_hat=reshape(Ybar_hat,[m,q]);
        Yinter=Y-Ybar_hat;
        [Uhat]=initAltGDMin(Yinter);
        [Uhat2, Bhat2]=GDMin_wi(T,Uhat,Yinter);
        xT=Uhat2*Bhat2;
        L(:,1:q)=xT+Xbar_hat;
        %         X_new_vec=reshape(L,[n1,n2,q])
        %         RMSE_modi(X_new_vec,x)
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        Ymec=Y-Afft(L);
         E_mec=[];
        for kk=1:1:q
            E_mec(:,kk)=cgls_modi(@Afft_modi,@At_modi, Ymec(:,kk) ,0,1e-36,30);
        end
        Xhat_GD_MEC1=L+E_mec;
        Xhat_GD_MEC=reshape(Xhat_GD_MEC1,[n1, n2,q]);
        
        Time_GD_MEC=  toc;
        %save('C:\Users\sbabu\Desktop\Mini-Batch\Mini_Batch_MEC_Sparse\golden_angle_and_radial_comparison\Xhat_GD_MEC.mat', 'Xhat_GD_MEC');
        % Time_GD_Sparse= [Time_GD_Sparse, toc];
        Error_GD_MEC=RMSE_modi(Xhat_GD_MEC,x);
        similarity_index=[];
        for i =1:1:q
            mssim=ssim(abs(Xhat_GD_MEC(:,:,i)/max(max(Xhat_GD_MEC(:,:,i)))),abs(x(:,:,i)/max(max(x(:,:,i)))));
            similarity_index(i)=mssim;
        end
        sim_GD_MEC=min(similarity_index)
        save('C:\Users\sbabu\Desktop\Results\low_res_8\Xhat_MGD_MEC.mat', 'Xhat_GD_MEC');
        %filename(ii)=name;
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%% AltgdMin  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        gg=mk(1:q);
        m=max(gg);
        Y=Y(1:m,1:q);
        Xhat1=[];
        L=[];
        T=70;
        pp=q;
        tic;
        %[Xbar_hat,flag,resNE,iter] = cgls(@Afft,@Att, Y,0,1e-36,10);
        %Ybar_hat=Afft(Xbar_hat);
        %         for i=1:1:q
        %             X_new(:,i)=Xbar_hat;
        %         end
        %         X_new_vec=reshape(X_new,[n1,n2,q])
        %         RMSE_modi(X_new_vec,x)
        %Ybar_hat=reshape(Ybar_hat,[m,q]);
        %Yinter=Y-Ybar_hat;
        [Uhat]=initAltGDMin(Y);
        [Uhat2, Bhat2]=GDMin_wi(T,Uhat,Y);
        xT=Uhat2*Bhat2;
        Xhat_GD1=[];
        Xhat_GD1(:,1:q)=xT;
        %         X_new_vec=reshape(L,[n1,n2,q])
        %         RMSE_modi(X_new_vec,x)
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %          Ymec=Y-Afft(L);
        %             for kk=1:1:q
        %                 E_mec(:,kk)=cgls_modi(@Afft_modi,@At_modi, Ymec(:,kk) ,0,1e-6,10);
        %             end
        %             Xrec=L+E_mec;
        %             Xhat_vec=reshape(Xrec,[n1, n2,q]);
        %             time=toc;
        %             RMSE_modi(Xhat_vec,x)
        
        
        
        Xhat_GD=reshape(Xhat_GD1,n1,n2,q);
        Time_GD=  toc;
        %save('C:\Users\sbabu\Desktop\Mini-Batch\Mini_Batch_MEC_Sparse\golden_angle_and_radial_comparison\Xhat_GD.mat', 'Xhat_GD');
        % Time_GD_Sparse= [Time_GD_Sparse, toc];
        Error_GD=RMSE_modi(Xhat_GD,x);
        similarity_index=[];
        for i =1:1:q
            mssim=ssim(abs(Xhat_GD(:,:,i)/max(max(Xhat_GD(:,:,i)))),abs(x(:,:,i)/max(max(x(:,:,i)))));
            similarity_index(i)=mssim;
        end
        sim_GD=min(similarity_index)
        %filename(ii)=name;
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        fprintf(fid, '%s(%d) & %8.4f (%5.2f,%8.4f)& %8.4f (%5.2f,%8.4f)& %8.4f (%5.2f,%8.4f)& %8.4f (%5.2f,%8.4f)& %8.4f (%5.2f,%8.4f) \n', name, radial(ii),Error_Ktslr,Time_Ktslr,sim_Ktslr,Error_LSparse,Time_LSparse,sim_LpS,Error_GD,Time_GD,sim_GD,Error_GD_MEC,Time_GD_MEC,sim_GD_MEC,Error_GD_Sparse,Time_GD_Sparse,sim_MGDS);
    end
    %p=[radial;Error_Ktslr; Time_Ktslr;Error_LSparse;Time_LSparse;Error_GD_Sparse;Time_GD_Sparse];
    
    
    
    
    
    %     p=[filename,radial;Error_GD_Sparse;Time_GD_Sparse];
    %     fid=fopen('AltGDMin_LSM.txt','w');
    %     fprintf(fid,'  %s(%s)     %s  \n','name','radial','AltGDMin');
    %     %     fprintf(fid,'  %s(%s)  &  %s  &  %s  &   %s  \n',name,'radial','k-t-SLR','L+S','AltGDMin');
    %     fprintf(fid,'  %s(%d)     & %8.4f (%2.4f) \n',p);
    %     fclose(fid);
end
fclose(fid);

function y=SoftThresh(x,p)
y=(abs(x)-p).*x./abs(x).*(abs(x)>p);
y(isnan(y))=0;
end