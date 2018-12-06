%Main Script for hard-kill bidirection evolution method
%*******************************************************
%By J S Yang
%Date: 2018-12-05
%*******************************************************

clear; close all; clc;

%Parameters
EvoluationRate = 0.02;      %Evolution rate
VolFracCon = 0.4;           %Volume constraints
IterNumMax = 1000;          %Maximum iteration number
ConvergeCondition = 1e-5;   %Converge Condition
IterNum = 0;                %Initial iternation number
Rmin = 4;                   %Filter Radium
% AddRateMax = 0.05;          %Maxmium element addation rate
% TargetVolFrac = 1 - EvoluationRate;

%Create folder for Design variables
if exist('DesignVariables','dir')==0
    mkdir('DesignVariables');
end 

%Create file to transfer iteration number to python script
save('IterNum.dat', 'IterNum', '-ascii');
ObjChange10 = 1;

while ObjChange10 > ConvergeCondition
    
    %Change of objective values in recent 10 loops
    if IterNum >= 10
        Obj = load('ModelTotExtWork.dat');
        ObjChange10 = abs(sum(Obj(end-9 : end-5)) - sum(Obj(end-4 : end))) / abs(sum(Obj(end-9 : end-5)));
    end

    %+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    % This is for high version Matlab with interface to python
    % %Call InpGenerater0.py to generate new *.inp file
    % import py.InpGenerater0.*
    % InpGenerater0(IterNum)
    %+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

    %+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    % This is for low version Matlab without interface to python
    %Call InpGenerater.py to generate new *.inp file
    dos('python InpGenerater.py', '-echo');
    %+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    
    %Run Abaqus in command window from *.inp file
    JobName = ['Job-Iter', num2str(IterNum)];
    JobRun = ['abaqus job=',JobName,' int'];
    % JobRun = 'abaqus job=Job-Iter1';
    % Attention: NO SPACE before and after '=' to avoid Abaqus Error
    % 'int' displays the Abaqus process: Run pre.exe ...
    dos(JobRun, '-echo');

    %Get element elastic strain energy from *.odb file
    ScriptName = 'OdbReader.py';
    ScriptRun = ['abaqus cae noGUI=',ScriptName];
    dos(ScriptRun, '-echo');

    if IterNum == 0
        %ȫ�嵥Ԫ���(��һ��)���뵥Ԫ����Ľڵ�
        ElementF  = load('ElementsFull.dat');
        %�ڵ���(��һ��)�Ͷ�Ӧ������
        NodesF = load('NodesFull.dat');
        CoordNum = length((NodesF(1,:))) - 1;   %Number of coordinates per node
        NodePerEle = length(ElementF(1,:)) - 1;   %Number of nodes per element
        EleCentersF = zeros(length(ElementF(:,1)), CoordNum + 1);
            
        %���㵥Ԫ���ĵ�����
        if CoordNum == 2                        %2d model
            NodesXF = NodesF(:, 2);
            EleNodesXF = NodesXF(ElementF(:, 2:end));
            NodesYF = NodesF(:, 3);
            EleNodesYF = NodesYF(ElementF(:, 2:end));
            EleCentersF(:,1) = ElementF(:,1);
            EleCentersF(:,2) = sum(EleNodesXF,2) / NodePerEle;
            EleCentersF(:,3) = sum(EleNodesYF,2) / NodePerEle;
            clear NodesXF NodesYF EleNodesXF EleNodesYF;
        elseif CoordNum == 3                    %3d model
            NodesXF = NodesF(:, 2);
            EleNodesXF = NodesXF(ElementF(:, 2:end));
            NodesYF = NodesF(:, 3);
            EleNodesYF = NodesYF(ElementF(:, 2:end));
            NodesZF = NodesF(:, 4);
            EleNodesZF = NodesZF(ElementF(:, 2:end));
            EleCentersF(:,1) = ElementF(:, 1);
            EleCentersF(:,2) = sum(EleNodesXF,2) / NodePerEle;
            EleCentersF(:,3) = sum(EleNodesYF,2) / NodePerEle;
            EleCentersF(:,4) = sum(EleNodesZF,2) / NodePerEle;
            clear NodesXF NodesYF NodesZF EleNodesXF EleNodesYF EleNodesZ
        end
        
        NodeCoordTmp = NodesF(:, 2:end);        %ֻ��������ֵ,ÿ��һ���ڵ�
        EleNodesTmp = ElementF(:, 2:end);       %ֻ�����ڵ���,ÿ��һ����Ԫ
        EleCentersTmp = EleCentersF(:,2:end);   %ֻ�������ĵ�����,ÿ��һ����Ԫ
        
        %�������нڵ������е�Ԫ���ĵ�ľ���
        NodEleDispF = pdist2(NodeCoordTmp, EleCentersTmp);
        
        %�жϵ�Ԫ�ͽڵ�������ϵ
        NodeEleConnect = zeros(length(NodesF(:,1)),length(ElementF(:,1)));
        for jj = 1:1:length(NodesF(:,1))
            [RTmp,CTmp] = find(EleNodesTmp == NodesF(jj,1));
            NodeEleConnect(jj,RTmp) = 1;
        end
        %ÿ���ڵ�����ĵ�Ԫ����
        NodConnectNum = sum(NodeEleConnect,2);
        %ǿ��,��ֹ�����ȴӵ�Ԫ��ڵ㴫��ʱ��0��
        NodConnectNum(NodConnectNum==1) = 2;
        NodConnectNumF = repmat(NodConnectNum,1,length(ElementF(:,1)));
        
        %ֻ�����������ϵ�ľ���,��������
        NodEleDispC = NodEleDispF .* NodeEleConnect;
        
        %ÿ���ڵ㵽��֮�������ϵ�ĵ�Ԫ���ľ���֮��
        NodEleDispCS = sum(NodEleDispC,2);
        NodEleDispCSF = repmat(NodEleDispCS,1,length(ElementF(:,1)));

        %ǿ��,������һ����Ԫ����Ľڵ���õ�Ԫ���ĵľ���ӱ�,������˾���Ԫ��Ϊ0
        NodEleDispCT = NodEleDispC;
        for kk = 1:1:length(NodEleDispCT(:,1))
            if sum(NodEleDispCT(kk,:)>0) == 1
                NodEleDispCT(kk,:) = 2 * NodEleDispCT(kk,:);
            end
        end

        %����һ���޸Ķ�Ӧ,����ֵ��Ϊ��ֵ
        %�ӵ�Ԫ�����ȵ��ڵ������ȵĹ��˾���
        EleSen2NodeM = abs((1.0 * (NodEleDispCT>0) - NodEleDispCT ./ NodEleDispCSF) ./ (NodConnectNumF - 1));
        %clear NodConnectNumF;

        %�ӽڵ������ȵ���Ԫ�����ȵĹ��˾���
        NodEleDispC = max(Rmin - NodEleDispF, 0);
        NodEleDispCSF = repmat(sum(NodEleDispC,2),1,length(ElementF(:,1)));
        NodeSen2EleM = (NodEleDispC ./ NodEleDispCSF)';
    end

    % %��ǰѭ����Ŀ���������
    % if IterNum >= 1
    %     if TargetVolFrac > VolFracCon
    %         TargetVolFrac = TargetVolFrac * (1 - EvoluationRate);
    %     elseif TargetVolFrac < VolFracCon
    %         TargetVolFrac = TargetVolFrac * (1 + EvoluationRate);
    %     else
    %         TargetVolFrac = VolFracCon;
    %     end
    % end
    TargetVolFrac = (1-EvoluationRate) ^ (IterNum + 1);
    TargetVolFrac = max(TargetVolFrac, VolFracCon);

    %Get Element elastic energy density as sensitivity
    EleElasEnerDen0 = load('EleElasEnerDen.dat');
    EleElasEnerDenID = EleElasEnerDen0(:,1);
    EleElasEnerDen = EleElasEnerDen0(:,2);

    %Design Variables
    if IterNum == 0
        DV = ones(size(EleElasEnerDen));
        save('./DesignVariables/DV_Iter0.dat','DV','-ascii');
    end

    %��Ϊ��Щ��Ԫ�������Ȳ�����,��Ҫ��ȫΪ0
    EleSensitivity = zeros(size(ElementF(:,1)));
    if sum(DV==1) == length(EleElasEnerDen) 
        EleSensitivity(EleElasEnerDenID) = EleElasEnerDen;
    else
        error('Number of existed element not equal to the number of nonzero elements in DV!');
    end

    %����Ԫ�������䵽�ڵ���
    %��ʼ���ڵ�������
    if IterNum == 0
        NodeSen = zeros(size(NodesF(:,1)));
    end
    %�����ȷ���
    for ii = 1:1:length(NodeSen)
        NodeSen(ii) = EleSen2NodeM(ii,:) * EleSensitivity;
    end
    %���ڵ����������·������Ԫ
    %��ʼ�����˺�ĵ�Ԫ������
    if IterNum == 0
        EleSenFiltered = zeros(size(EleSensitivity));
    end
    %�����ȷ���
    for jj = 1:1:length(EleSenFiltered)
        EleSenFiltered(jj) = NodeSen2EleM(jj,:) * NodeSen;
    end

    %Average the filtered element sensitivity bewteen the last and current loop for algorithm staibility.
    if IterNum >= 1
        EleSenFiltered = (EleSenFiltered + EleSenFilteredO) / 2.0;
    end
    
    %Bi-section methods for critical element sensitivity
    EleSenH = max(EleSenFiltered);
    EleSenL = min(EleSenFiltered);
    while abs((EleSenH - EleSenL) / EleSenH) > 10e-10
        EleSenCr = (EleSenH + EleSenL) / 2;
        DV = 1.0 * (EleSenFiltered > EleSenCr);
        if sum(DV) > TargetVolFrac * length(DV)
            EleSenL = EleSenCr;
        else
            EleSenH = EleSenCr;
        end
    end
    
%*******************************************************************************************
%     %���Ӷ���û��ʲô��
%     %����������
%     [OrdEleSenFiltered,Ord] = sort(EleSenFiltered);
% 
%     %��һ����������ֵ
%     %����Ҫ��ÿ����Ԫ�����ȣ���˿��ԸĽ�Ϊ��ȡ��Ԫ���
%     EleSenCr = OrdEleSenFiltered(round(length(ElementF(:,1)) * TargetVolFrac));
% 
%     %����ֱ����ɾ��Ԫ
%     DVTryR = DV;
%     DVTryR(EleSenFiltered < EleSenCr) = 0;
%     DVTryA = DVTryR;
%     DVTryA(EleSenFiltered > EleSenCr) = 1;
%     %��Ԫ������
%     AddRate = (DVTryA - DVTryR) / length(ElementF(:,1));
%     %����Ԫ���ӹ���
%     if AddRate > AddRateMax
%         DVTryA = DV;
%         % VoidEle = find(DV == 0);
%         %�������Ԫ������ȷ�����ӵ�Ԫ������
%         VoidEleSen = EleSenFiltered(DVTryA == 0);
%         [OrdVoidEleSen,~] = sort(VoidEleSen);
%         NAdd = round(AddRateMax * length(ElementF(:,1)));
%         % DVTryA = DVTryA(VESOrd(end-NAdd+1:end));
%         %��Ԫ���ӵ��ٽ�������
%         EleSenCrA = OrdVoidEleSen(end-NAdd);
%         %���ӵ�Ԫ
%         DVTryA(EleSenFiltered > EleSenCrA) = 1;
%         %����Ŀ�������ȷ����Ҫɾ���ĵ�Ԫ����
%         DVTryR = DVTryA;
%         NRemove = sum(DVTryR) - TargetVolFrac * length(ElementF(:,1));
%         SolidEleSen = EleSenFiltered(DVTryR == 1);
%         [OrdSolidEleSen,~] = sort(SolidEleSen);
%         %��Ԫɾ�����ٽ�������
%         EleSenCrR = OrdSolidEleSen(NRemove+1);
%         %�Ƴ���Ԫ
%         DVTryR(EleSenFiltered < EleSenCrR) = 0;
%         DV = DVTryR;
%     else
%         DV = DVTryA;
%     end
%*******************************************************************************************

    % Save design variables to files
    DVName = ['./DesignVariables/DV_Iter',num2str(IterNum + 1),'.dat'];
    save(DVName,'DV','-ascii');

    %Save the last filterd element sensitivity
    EleSenFilteredO = EleSenFiltered;

    %Update the iteration counter
    IterNum = IterNum + 1;
    save('IterNum.dat', 'IterNum', '-ascii');
    
    % Max Iteration number
    if IterNum > IterNumMax
        break;
    end
end

%Get topology
dos('abaqus cae noGUI=PostProcessor.py','-echo');

%History curve plot
[DVHis,ObjValHis] = HistoryPlot;