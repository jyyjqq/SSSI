function seisplot(varargin)
% This function plot seismic data horizontally. Note that the first
% dimension is assumed as time dimension and the second dimension is trace
% dimension. 


if nargin < 2
    t = [];
    x = varargin{1};
    if size(x,1) < size(x,2)
        x  = x';
    end
elseif nargin < 3
    t = varargin{1};
    x = varargin{2};
    if size(x,1) < size(x,2)
        x  = x';
    end
    if length(t) ~= size(x,1)
        error('Vectors must be the same lengths.');
    end
end


N = size(x,2);

figure;
hold on
for i = 1 : N
    data = x(:,i);
    % scale data by largest magnitude, between -0.5 and 0.5
    data = data/(2*max(abs(data))); 
    data(1) = 0;
    data = data - i;
    if isempty(t)
        plot(data,'-k');
    else
        switch mod(i,3)
            case 0
                plot(t,data,'k');
            case 1
                plot(t,data,'b');
            case 2
                plot(t,data,'r');
        end
    end
end
hold off

