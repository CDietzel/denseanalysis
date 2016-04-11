classdef test_structobj < matlab.unittest.TestCase
    % Unittests for structobj
    %
    %   This suite of unittests ensures a minimum level of performance for
    %   the strucobject class. It can be called directly or indirectly as
    %   part of a larger suite.
    %
    % USAGE:
    %   alltests = tests();     % Get all tests within this file to be run

    % Copyright (c) <2016> Jonathan Suever (suever@gmail.com
    % All rights reserved
    %
    % This software is licensed using the 3-clause BSD license.

    methods (Test)
        function emptyConstructor(testCase)
            % Create a structobj object without specifying inputs
            I = structobj();

            testCase.assertNumElements(I, 1, ...
                'Expected a single instance');
        end

        function testMultiDimConstructor(testCase)
            % Create a multi-dimensional object using a multi-dim structure
            sz = [4 2];
            inputs = repmat(struct(), sz);

            I = structobj(inputs);

            testCase.assertSize(I, sz, ...
                'Should be the same size as the inputs');
            testCase.assertEqual(struct(I), inputs);
        end

        function testStructConstructor(testCase)
            % Test passing in input arguments to struct
            I = structobj('Key1', 'value1', 'Key2', 'value2');

            testCase.assertNumElements(I, 1, 'Expected single instance');

            testCase.assertEqual(fieldnames(I), {'Key1'; 'Key2'});
        end

        function testMultiStructConstructor(testCase)
            % Test passing in multiple input arguments to struct
            I = structobj('Key1', {'a', 'b'}, 'Key2', {'c', 'd'});

            testCase.assertSize(I, [1 2], 'Unexpected size')
            testCase.assertEqual(fieldnames(I), {'Key1'; 'Key2'});

            testCase.assertEqual(I(1).Key1, 'a');
            testCase.assertEqual(I(2).Key1, 'b');
            testCase.assertEqual(I(1).Key2, 'c');
            testCase.assertEqual(I(2).Key2, 'd');
        end

        function testSaveLoad(testCase)
            % Uses loadobj to reload from structure generated by saveobj
            inputs = struct('One', 1, 'Two', 2);

            I = structobj(inputs);

            S = saveobj(I);

            testCase.assertClass(S, 'struct', ...
                'Saveobj returned something other than a struct');

            testCase.assertEqual(S, inputs, ...
                'Expected the inputs and saveobj to be the same');

            % Now try to load it back in
            I2 = structobj.loadobj(S);

            testCase.assertClass(I2, 'structobj', ...
                'Loadobj returned the wrong data type');

            testCase.assertEqual(struct(I2), S, ...
                'Loaded data is not equal to the inputs');

            testCase.assertNotSameHandle(I2, I, ...
                'A clone was made rather than a copy');
        end

        function testSaveLoad2File(testCase)
            % Save object to file and reload successfully
            fname = sprintf('%s.mat', dicomuid);
            testCase.addTeardown(@()delete(fname));

            inputs = struct('One', 1, 'Two', 2);

            I = structobj(inputs);

            save(fname, 'I');

            loaded = load(fname, '-mat');

            testCase.assertEqual(struct(loaded.I), struct(I), ...
                'The loaded object does not match the saved object');
            testCase.assertNotSameHandle(loaded.I, I, ...
                'Somehow we ended up with a clone??');
        end

        function testMultiSaveLoad(testCase)
            % Save an array of objects to file and reload succesfully
            inputs = struct('One', {1, 2; 3, 4}, 'Two', {2, 10; 34, 2});

            I = structobj(inputs);

            S = saveobj(I);

            testCase.assertClass(S, 'struct', ...
                'Saveobj returned something other than a struct');

            testCase.assertSize(S, size(inputs), ...
                'Expected the inputs and saveobj to be the same');

            % Now try to load it back in
            I2 = structobj.loadobj(S);

            testCase.assertClass(I2, 'structobj', ...
                'Loadobj returned the wrong data type');

            testCase.assertEqual(struct(I2), S, ...
                'Loaded data is not equal to the inputs');

            testCase.assertNotSameHandle(I2, I, ...
                'A clone was made rather than a copy');
        end

        function testEmpty(testCase)
            % Create an empty object (size = [0,0])
            empty = structobj.empty();

            testCase.assertClass(struct(empty), 'struct');
            testCase.assertSize(empty, [0 0]);
            testCase.assertSize(struct(empty), [0 0]);
        end

        function testMultiDimEmpty(testCase)
            % Create a multi-dimensional empty object (size = [0,2])
            empty = structobj.empty(0,2);

            testCase.assertClass(struct(empty), 'struct');
            testCase.assertSize(empty, [0 2]);
            testCase.assertSize(struct(empty), [0 2]);
        end

        function testMultiSaveLoadFile(testCase)
            % Save a multi-dimensional object to file and reload
            fname = sprintf('%s.mat', dicomuid);
            testCase.addTeardown(@()delete(fname));

            inputs = struct('One', {1, 2; 3, 4}, 'Two', {2, 10; 34, 2});

            I = structobj(inputs);

            save(fname, 'I');

            loaded = load(fname, '-mat');

            testCase.assertEqual(struct(loaded.I), struct(I), ...
                'The loaded object does not match the saved object');
            testCase.assertSize(loaded.I, size(inputs), ...
                'The size is mis-matched upon loading');
            testCase.assertNotSameHandle(loaded.I, I, ...
                'Somehow we ended up with a clone??');
        end

        function testStruct(testCase)
            % Convert structobj object to a structure
            inputs = struct('Doctor', {'Who'}, 'BBC', {'America'});

            I = structobj(inputs);
            S = struct(I);

            testCase.assertSize(S, size(inputs));
            testCase.assertEqual(S, inputs);
            testCase.assertClass(S, 'struct');
        end

        function testSubStruct(testCase)
            % Index into a multi-dimensional structobj object
            inputs = struct('Beatles', {'John', 'Paul', 'Ringo', 'George'}, ...
                            'Monkees', {'Peter', 'Micky', 'Davy', 'Michael'});

            bands = structobj(inputs);

            leadSingers = bands(1);

            expected = struct('Beatles', {'John'}, 'Monkees', {'Peter'});

            substruct = struct(leadSingers);

            testCase.assertEqual(substruct, expected);

            testCase.assertEqual(leadSingers, bands(1));
            testCase.assertSameHandle(leadSingers, bands(1));

            % Now make a change real quick and make sure it applies
            % backwards
            leadSingers.Beatles = 'Yoko';

            testCase.assertEqual(bands(1).Beatles, leadSingers.Beatles);
        end

        function testUpdateFromStructMultiDim(testCase)
            % Update multiple objects with a multi-dim struct

            inputs1 = struct('one', {1.1, 2.3}, 'two', {1.2, 3.4});
            inputs2 = struct('one', {1.2, 3.4}, 'two', {2.2, 5.6});

            info1 = structobj(inputs1);

            update(info1, inputs2);

            for field = fieldnames(info1)'
                for k = 1:numel(info1)
                    testCase.assertEqual(inputs2(k).(field{1}), ...
                                         info1(k).(field{1}));
                end
            end
        end

        function testUpdateFromStructObjMultiDim(testCase)
            % Update multiple objects with a multi-dim structobj

            inputs1 = struct('one', {1.1, 2.3}, 'two', {1.2, 3.4});
            inputs2 = struct('one', {1.2, 3.4}, 'two', {2.2, 5.6});

            info1 = structobj(inputs1);
            info2 = structobj(inputs2);

            update(info1, info2);

            for field = fieldnames(info1)'
                for k = 1:numel(info1)
                    testCase.assertEqual(info2(k).(field{1}), ...
                                         info1(k).(field{1}));
                end
            end
        end

        function testUpdateFromStructReplace(testCase)
            % Update an structobj with a structure

            inputs1 = struct('one', 1.1, 'two', 1.2);
            inputs2 = struct('one', 1.2, 'two', 2.2);

            info1 = structobj(inputs1);

            update(info1, inputs2);

            for field = fieldnames(info1)'
                testCase.assertEqual(inputs2.(field{1}), info1.(field{1}));
            end
        end

        function testUpdateFromStructAdd(testCase)
            % Add new fields to structobj using a struct

            inputs1 = struct('one', 1, 'two', 2);
            inputs2 = struct('three', 3, 'four', 4);

            info1 = structobj(inputs1);

            fields = cat(1, fieldnames(info1), fieldnames(inputs2));

            update(info1, inputs2);

            testCase.assertEqual(sort(fieldnames(info1)), sort(fields));

            for field = fieldnames(inputs2)'
                testCase.assertEqual(inputs2.(field{1}), info1.(field{1}));
            end

            for field = fieldnames(inputs1)'
                testCase.assertEqual(info1.(field{1}), inputs1.(field{1}));
            end
        end

        function testUpdateFromStructObjReplace(testCase)
            % Ensure that we can update an object with another

            inputs1 = struct('one', 1.1, 'two', 1.2);
            inputs2 = struct('one', 1.2, 'two', 2.2);

            info1 = structobj(inputs1);
            info2 = structobj(inputs2);

            update(info1, info2);

            for field = fieldnames(info1)'
                testCase.assertEqual(info2.(field{1}), info1.(field{1}));
            end
        end

        function testUpdateFromStructObjAdd(testCase)
            % Add new fields to structobj using an structobj object

            inputs1 = struct('one', 1, 'two', 2);
            inputs2 = struct('three', 3, 'four', 4);

            info1 = structobj(inputs1);
            info2 = structobj(inputs2);

            fields = cat(1, fieldnames(info1), fieldnames(info2));

            update(info1, info2);

            testCase.assertEqual(sort(fieldnames(info1)), sort(fields));

            for field = fieldnames(info2)'
                testCase.assertEqual(info2.(field{1}), info1.(field{1}));
            end

            for field = fieldnames(inputs1)'
                testCase.assertEqual(info1.(field{1}), inputs1.(field{1}));
            end
        end

        function testFieldnames(testCase)
            % Retrieve fieldnames of the structobj object
            inputs = struct('A', {1}, 'B', {2}, 'C', {3});

            I = structobj(inputs);

            expected = {'A'; 'B'; 'C'};

            testCase.assertEqual(fieldnames(I), expected);

            % Now make sure that if we just append this that we get the
            % same thing
            inputs = cat(1, inputs, inputs);

            I2 = structobj(inputs);

            testCase.assertEqual(fieldnames(I2), expected);
        end

        function testVerticalConcatenation(testCase)
            % Concatenate objects in the vertical (1st) dimension
            inputs = struct('A', {1}, 'B', {2}, 'C', {3});

            I = structobj(inputs);

            inputs2 = cat(1, inputs, inputs);

            I2 = structobj(inputs2);

            I3 = [I; I];

            I4 = cat(1, I, I);

            I5 = vertcat(I, I);

            testCase.assertSize(I3, [2 1]);
            testCase.assertEqual(struct(I3), struct(I2));
            testCase.assertEqual(struct(I4), struct(I2));
            testCase.assertEqual(struct(I5), struct(I2));
        end

        function testHorizontalConcatenation(testCase)
            % Concatenate objects in the horizontal (2nd) dimension
            inputs = struct('A', {1}, 'B', {2}, 'C', {3});

            I = structobj(inputs);

            inputs2 = cat(2, inputs, inputs);

            I2 = structobj(inputs2);

            I3 = [I, I];

            I4 = cat(2, I, I);

            I5 = horzcat(I, I);

            testCase.assertSize(I3, [1 2]);
            testCase.assertEqual(struct(I3), struct(I2));
            testCase.assertEqual(struct(I4), struct(I2));
            testCase.assertEqual(struct(I5), struct(I2));
        end

        function testRemoveField(testCase)
            % Remove a field from the object
            inputs = struct('A', {1}, 'B', {2}, 'C', {3});

            I = structobj(inputs);

            rmfield(I, 'B');    %#ok

            testCase.assertSize(I, size(inputs));
            testCase.assertEqual(fieldnames(I), {'A'; 'C'})

            inputs = struct('A', {1,2}, 'B', {2,3}, 'C', {3,4});

            I = structobj(inputs);

            rmfield(I, 'C');    %#ok

            testCase.assertSize(I, size(inputs));
            testCase.assertEqual(fieldnames(I), {'A'; 'B'})
        end

        function testAssignment(testCase)
            % Add new field and value to an existing object
            inputs = struct('Odd', {1, 3, 5}, 'Even', {2, 4, 6});

            I = structobj(inputs);

            % Now assign a single value
            I(1).Odd = 7;
            testCase.assertEqual([I.Odd], [7 3 5]);

            % Assign all values
            [I.Odd] = deal(11,13,15);
            testCase.assertEqual([I.Odd], [11 13 15]);
        end

        function testOrderFields(testCase)
            % Sort the fields of the object in the specified order
            inputs = struct('B', {1}, 'A', {2}, 'C', {3});

            fields = fieldnames(inputs);
            [sfields, isort] = sort(fields);

            I = structobj(inputs);

            [I,perm] = orderfields(I);

            testCase.assertSize(I, size(inputs));
            testCase.assertEqual(fieldnames(I), sfields);
            testCase.assertEqual(perm, isort);

            inputs = struct('B', {1,2; 3 4}, 'A', {2, 4; 7 8}, 'C', {3, 1; 2 4});

            fields = fieldnames(inputs);
            [sfields, isort] = sort(fields);

            I = structobj(inputs);

            [I,perm] = orderfields(I);

            testCase.assertSize(I, size(inputs));
            testCase.assertEqual(fieldnames(I), sfields);
            testCase.assertEqual(perm, isort);
        end

        function testExpansion(testCase)
            % Expand data from multi-dim object to an array implicitly

            % If we have multiple elements they should be concatenated
            indata = [1 2; 3 4];
            celldata = num2cell(indata);

            inputs = struct('Garbage', celldata);

            obj = structobj(inputs);

            testCase.assertSize(obj, size(indata));

            newdata = [inputs.Garbage];

            testCase.assertSize(newdata, [1 numel(indata)]);
            testCase.assertEqual(newdata, indata(:)');

            % Now check out cell flattening
            newdata = {inputs.Garbage};

            testCase.assertSize(newdata, [1 numel(indata)]);
            testCase.assertEqual(newdata, celldata(:)');
        end

        function testCopy(testCase)
            % Copy the object by value not by reference
            inputs = struct('Fornwalt', {1, 2}, 'Lab', {'DENSE', 'MRI'});

            I = structobj(inputs);

            I2 = copy(I);

            testCase.assertEqual(struct(I), struct(I2), ...
                'The copy operation yielded a different object');
            testCase.assertNotSameHandle(I, I2, ...
                'Your object is a clone rather than a copy');
        end

        function testGetFieldDefault(testCase)
            % Specify default value to be returned from getfield
            S = structobj('a', 2);

            % Existing field and no default
            values = getfield(S, 'a');  %#ok
            testCase.assertEqual(values, S.a);

            % Non-existent field with default
            values = getfield(S, 'b', 'value');
            testCase.assertEqual(values, 'value');

            % Get the ID of the error we expect
            str = struct(S);
            try str.c; catch ME; end

            % Non-existent field no default
            errorFunc = @()getfield(S, 'c');  %#ok
            testCase.assertError(errorFunc, ME.identifier)
        end

        function testNestedObjectsReferencing(testCase)
            % Nest a structobj inside of a structobj
            S = structobj('a',{structobj('b',2,'c',{structobj('d',4)})});

            testCase.assertEqual(fieldnames(S), {'a'});
            testCase.assertClass(S.a, 'structobj');
            testCase.assertClass(S.a.c, 'structobj');

            % Make sure we can use subsref appropriately
            testCase.assertEqual(S.a.b, 2);
            testCase.assertEqual(S.a.c.d, 4);
        end

        function testNestedObjectsAssignment(testCase)
            % Assignment to nested substruct objects
            S = structobj('a', {structobj('b', 2)});

            % Check out subsasgn
            S.a.b = 4;
            testCase.assertEqual(S.a.b, 4);

            % Assign yet another nested amount
            newval = structobj('c', 3);
            S.a.b = newval;

            testCase.assertSameHandle(S.a.b, newval);
            testCase.assertEqual(S.a.b.c, 3);
        end

        function subscriptedAssignment(testCase)
            s = structobj('a', 1);

            % Constructor worked as expected
            testCase.assertEqual(s.a, 1);

            % Can assign using () and .
            s(1).a = 2;
            testCase.assertEqual(s.a, 2);

            % Add another structobj to create an array
            s = cat(2, s, structobj('a', 1));

            % Assign using () and .
            s(1).a = 3;
            testCase.assertEqual(s(1).a, 3);
            testCase.assertEqual(s(2).a, 1);

            % Assign to the other element using () and .
            s(2).a = 4;
            testCase.assertEqual(s(1).a, 3);
            testCase.assertEqual(s(2).a, 4);
        end

        function subscriptedAssignmentIdentical(testCase)
            s = structobj('a', 1);
            s = [s, s];

            testCase.assertSize(s, [1 2]);

            testCase.assertEqual(s(1).a, 1)
            testCase.assertEqual(s(2).a, 1)

            origs = s;

            s(1).a = 2;

            testCase.assertSameHandle(origs, s);

            testCase.assertEqual(s(1).a, 2)
            testCase.assertEqual(s(2).a, 2)
        end
    end
end
